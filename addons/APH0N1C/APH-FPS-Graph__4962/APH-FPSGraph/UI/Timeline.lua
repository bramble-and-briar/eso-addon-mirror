--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

local FG = APHFPSGraphCore
local T = {}
FG.Timeline = T

local floor, ceil, max, min = math.floor, math.ceil, math.max, math.min
local THEME = LibAPH.THEME

local NAME = "APHFPSGraphTimeline"
local TEXT_LEVEL = 10
local HEADER_H = 30
local PAD = 12
local AXIS_W = 52
local BASE_FONT = 13
local MIN_FONT, MAX_FONT = 11, 20
local MIN_W, MIN_H = 520, 300
local MAX_W, MAX_H = 1800, 1100
local MAX_SLICES = 120
local MIN_SPAN = 0.01
local ZOOM_STEP = 0.5
local WHEEL_STEP = 0.8
local PAN_STEP = 0.25
local BTN_W = 78
local GRID_STEPS = 4
local PING_W = 46
local DOT = 3
local RANGE_ALPHA = 0.4
local TICK_STEPS = { 1, 2, 5, 10, 15, 30, 60, 120, 300, 600, 900, 1800, 3600 }
local TARGET_TICKS = 6
local FONT_FACE = IsConsoleUI() and "$(GAMEPAD_MEDIUM_FONT)" or "$(BOLD_FONT)"
local TITLE_BAR = { 0, 0, 0, 0.92 }
local PING_COLOR = { 0.35, 0.9, 0.95 }
local LOAD_COLOR = { 1, 0.6, 0.15 }
local RELOAD_COLOR = { 0.8, 0.45, 1 }
local MARK_W = 2
local PAD_TAP_PX = 4
local PAN_EDGE_SHARE = 0.1
local CURSOR_COLOR = { 1, 1, 1, 0.45 }

T.MIN_W, T.MIN_H = MIN_W, MIN_H

local win, title, detail, empty, sticky, position, mover, resizer
local panels = {}
local built = false
local font_size = BASE_FONT
local view_from, view_to = 0, 1
local min_span = MIN_SPAN
local view_key
local drag
local cursor, cursor_slot

local function Saved() return FG.saved end
local function IsPad() return IsConsoleUI() or IsInGamepadPreferredMode() end

local function Font()
	return FONT_FACE .. "|" .. font_size .. "|soft-shadow-thin"
end

local function Label(parent, suffix, color)
	local label = WINDOW_MANAGER:CreateControl(NAME .. suffix, parent, CT_LABEL)
	label:SetFont(Font())
	local c = color or THEME.TEXT
	label:SetColor(c[1], c[2], c[3], 1)
	label:SetMaxLineCount(1)
	label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
	LibAPH.RaiseLabel(label, { level = TEXT_LEVEL, backdrop = false })
	return label
end

local function Texture(parent, name)
	local tex = WINDOW_MANAGER:CreateControl(name, parent, CT_TEXTURE)
	tex:SetMouseEnabled(false)
	return tex
end

local function Paint(control, color, alpha)
	control:SetColor(color[1], color[2], color[3], alpha or color[4] or 1)
end

function T.Source()
	if FG.view.show then return FG.view.show end
	return FG.Sampler.RecordingStats() or FG.Sampler.SessionStats()
end

local function Length(run)
	return run.seconds or (#(FG.Lists(run).fps or {}) * (run.step_ms or 500) / 1000)
end

function T.Slices(run, from, to, limit)
	local lists = FG.Lists(run)
	local n = lists.fps and #lists.fps or 0
	local out = {}
	if n == 0 then return out end
	local first = min(n, floor(from * n) + 1)
	local last = max(first, min(n, ceil(to * n)))
	local count = last - first + 1
	local slices = min(limit or MAX_SLICES, count)
	local seconds = Length(run)
	for i = 1, slices do
		local a = first + floor((i - 1) * count / slices)
		local b = max(a, first + floor(i * count / slices) - 1)
		local fps, low, ping = 0, math.huge, nil
		for k = a, b do
			fps = fps + lists.fps[k]
			if lists.low[k] < low then low = lists.low[k] end
			local p = lists.ping and lists.ping[k]
			if p and (not ping or p > ping) then ping = p end
		end
		out[i] = {
			fps = fps / (b - a + 1), low = low, ping = ping,
			from_s = (a - 1) / n * seconds, to_s = b / n * seconds,
		}
	end
	for _, event in ipairs(run.events or {}) do
		for i, slice in ipairs(out) do
			if event.at >= slice.from_s and (event.at < slice.to_s or (i == #out and event.at <= slice.to_s)) then
				slice.events = slice.events or {}
				slice.events[#slice.events + 1] = event
				break
			end
		end
	end
	return out
end

function T.TickStep(span)
	for _, step in ipairs(TICK_STEPS) do
		if span / step <= TARGET_TICKS then return step end
	end
	return TICK_STEPS[#TICK_STEPS]
end

function T.GetView() return view_from, view_to end

function T.SetView(from, to)
	local span = zo_clamp(to - from, min_span, 1)
	if from < 0 then from = 0 end
	if from + span > 1 then from = 1 - span end
	view_from, view_to = from, from + span
	T.Refresh()
	return view_from, view_to
end

function T.Zoom(factor, center)
	local span = view_to - view_from
	center = center or (view_from + span / 2)
	local new_span = zo_clamp(span * factor, min_span, 1)
	local ratio = span > 0 and (center - view_from) / span or 0.5
	return T.SetView(center - new_span * ratio, center - new_span * ratio + new_span)
end

function T.Pan(amount)
	local span = view_to - view_from
	return T.SetView(view_from + span * amount, view_to + span * amount)
end

function T.ZoomIn() return T.Zoom(ZOOM_STEP, IsPad() and cursor or nil) end
function T.ZoomOut() return T.Zoom(1 / ZOOM_STEP, IsPad() and cursor or nil) end
function T.PanLeft() return T.Pan(-PAN_STEP) end
function T.PanRight() return T.Pan(PAN_STEP) end
function T.ResetZoom() return T.SetView(0, 1) end

function T.IsZoomed()
	return view_from > 1e-9 or view_to < 1 - 1e-9
end

local function Pool(panel, list, prefix, i, parent)
	local item = panel[list][i]
	if not item then
		item = Texture(parent or panel.plot, panel.prefix .. prefix .. i)
		panel[list][i] = item
	end
	return item
end

local measure

local function TextWidth(text)
	if not measure then
		measure = Label(win, "Measure")
		measure:SetHidden(true)
		measure:SetWrapMode(TEXT_WRAP_MODE_TRUNCATE)
	end
	measure:SetFont(Font())
	measure:SetText(text)
	local width = measure:GetTextWidth()
	return type(width) == "number" and width or #text * font_size * 0.6
end

local function AxisLabel(panel, list, i)
	local label = panel[list][i]
	if not label then
		label = Label(win, panel.suffix .. list .. i, THEME.MUTED)
		panel[list][i] = label
	end
	label:SetFont(Font())
	return label
end

local function SliceText(slice)
	local text = FG.L("TIMELINE_SLICE", FG.FormatDuration(slice.from_s), FG.FormatDuration(slice.to_s),
		FG.Graph.Fmt(slice.fps), FG.Graph.Fmt(slice.low))
	if slice.ping then text = text .. "   " .. FG.L("LINE_PING", slice.ping) end
	for _, event in ipairs(slice.events or {}) do
		text = text .. "   " .. FG.L(event.k == "reload" and "SLICE_RELOAD" or "SLICE_LOAD", event.s)
	end
	return text
end

local function DefaultDetail()
	local run = T.Source()
	local worst
	for _, slice in ipairs(T.Slices(run, 0, 1, MAX_SLICES)) do
		if not worst or slice.low < worst.low then worst = slice end
	end
	local text = worst and FG.L("TIMELINE_WORST", FG.Graph.Fmt(worst.low), FG.FormatDuration(worst.from_s)) or ""
	if not IsPad() then text = text .. (text ~= "" and "   " or "") .. FG.L("WHEEL_TO_ZOOM") end
	return text
end

local function StopDrag()
	drag = nil
	if win then win:SetHandler("OnUpdate", nil) end
end

local function OnDragUpdate()
	if not drag then return end
	local x = GetUIMousePosition()
	local shift = -(x - drag.x) / max(drag.width, 1) * drag.span
	if math.abs(shift) > 1e-9 then T.SetView(drag.from + shift, drag.from + shift + drag.span) end
end

local function OnHover(area)
	local panel = panels[area.fg_panel]
	local slice = panel and panel.slices and panel.slices[area.fg_slice]
	if slice then detail:SetText(SliceText(slice)) end
end

local function CursorShare()
	local span = view_to - view_from
	if not cursor then cursor = view_from + span / 2 end
	cursor = zo_clamp(cursor, view_from, view_to)
	return span > 0 and (cursor - view_from) / span or 0.5
end

local function PlaceCursor(force)
	local panel = panels[1]
	if not (IsPad() and panel and panel.slices and #panel.slices > 0 and not panel.plot:IsHidden()) then return false end
	local share = CursorShare()
	for _, other in ipairs(panels) do
		if other.slices and #other.slices > 0 and not other.plot:IsHidden() then
			local w = other.plot:GetWidth()
			other.cursor:ClearAnchors()
			other.cursor:SetAnchor(TOPLEFT, other.plot, TOPLEFT, zo_clamp(share * w, 0, max(w - 1, 0)), 0)
			other.cursor:SetDimensions(1, other.plot:GetHeight())
			other.cursor:SetHidden(false)
		end
	end
	local slot = zo_clamp(floor(share * #panel.slices) + 1, 1, #panel.slices)
	if force or slot ~= cursor_slot then
		cursor_slot = slot
		detail:SetText(SliceText(panel.slices[slot]))
	end
	return true
end

function T.MoveCursor(direction, pixels)
	if not T.IsShown() then return false end
	local panel = panels[1]
	if not panel or not panel.slices or #panel.slices == 0 then return false end
	local span = view_to - view_from
	local start = view_from + CursorShare() * span
	local target = zo_clamp(start + direction * (pixels or PAD_TAP_PX) / max(panel.plot:GetWidth(), 1) * span, 0, 1)
	if math.abs(target - start) < 1e-12 then return false end
	cursor = target
	if target > view_to then
		local to = min(target + span * PAN_EDGE_SHARE, 1)
		T.SetView(to - span, to)
	elseif target < view_from then
		local from = max(target - span * PAN_EDGE_SHARE, 0)
		T.SetView(from, from + span)
	else
		PlaceCursor()
	end
	return true
end

function T.GetCursor() return cursor end

local function OnLeave()
	if not detail then return end
	if not PlaceCursor(true) then detail:SetText(detail.fg_default or "") end
end

local function SliceCenter(area)
	local panel = panels[area.fg_panel]
	local count = panel and panel.slices and #panel.slices or 1
	local share = (area.fg_slice - 0.5) / max(count, 1)
	return view_from + (view_to - view_from) * share
end

local function OnWheel(area, delta)
	T.Zoom(delta > 0 and WHEEL_STEP or 1 / WHEEL_STEP, SliceCenter(area))
end

local function OnPress(area, button)
	if button ~= MOUSE_BUTTON_INDEX_LEFT then return end
	local panel = panels[area.fg_panel]
	drag = { x = GetUIMousePosition(), from = view_from, span = view_to - view_from, width = panel.plot:GetWidth() }
	win:SetHandler("OnUpdate", OnDragUpdate)
end

local function OnRelease(_, button, upInside)
	StopDrag()
	if upInside and button == MOUSE_BUTTON_INDEX_RIGHT then FG.Graph.OpenMenu(win) end
end

local function HitArea(panel, index, slot)
	local area = panel.hits[slot]
	if not area then
		area = WINDOW_MANAGER:CreateControl(panel.prefix .. "Hit" .. slot, panel.plot, CT_CONTROL)
		area:SetMouseEnabled(true)
		area:SetHandler("OnMouseEnter", OnHover)
		area:SetHandler("OnMouseExit", OnLeave)
		area:SetHandler("OnMouseWheel", OnWheel)
		area:SetHandler("OnMouseDown", OnPress)
		area:SetHandler("OnMouseUp", OnRelease)
		panel.hits[slot] = area
	end
	area.fg_panel, area.fg_slice = index, slot
	return area
end

local function Panel(index)
	local panel = panels[index]
	if panel then return panel end
	local suffix = index == 1 and "" or "Cmp"
	panel = { suffix = suffix, prefix = NAME .. suffix, bars = {}, ranges = {}, dots = {}, grid = {}, hits = {}, marks = {},
		y_labels = {}, x_labels = {}, p_labels = {} }
	panel.plot = WINDOW_MANAGER:CreateControl(panel.prefix .. "Plot", win, CT_CONTROL)
	local bg = Texture(panel.plot, panel.prefix .. "PlotBG")
	bg:SetAnchorFill(panel.plot)
	Paint(bg, THEME.INSET, 0.6)
	panel.name = Label(win, suffix .. "PanelName")
	panel.target = Texture(panel.plot, panel.prefix .. "Target")
	panel.target:SetHeight(1)
	panel.target:SetDrawLevel(3)
	Paint(panel.target, THEME.ACCENT, 0.8)
	panel.cursor = Texture(panel.plot, panel.prefix .. "Cursor")
	panel.cursor:SetDrawLevel(6)
	Paint(panel.cursor, CURSOR_COLOR)
	panel.cursor:SetHidden(true)
	panels[index] = panel
	return panel
end

local function HidePanel(panel)
	panel.plot:SetHidden(true)
	panel.name:SetHidden(true)
	panel.cursor:SetHidden(true)
	for _, list in ipairs({ "bars", "ranges", "dots", "grid", "hits", "marks", "y_labels", "x_labels", "p_labels" }) do
		for _, item in pairs(panel[list]) do item:SetHidden(true) end
	end
end

local function DrawGrid(panel, top, w, h, ping_top)
	for step = 0, GRID_STEPS do
		local y = h - step / GRID_STEPS * h
		local line = Pool(panel, "grid", "Grid", step)
		line:ClearAnchors()
		line:SetAnchor(TOPLEFT, panel.plot, TOPLEFT, 0, min(y, h - 1))
		line:SetDimensions(w, 1)
		Paint(line, THEME.STRIPE or THEME.TEXT, 0.12)
		line:SetHidden(false)
		local label = AxisLabel(panel, "y_labels", step)
		local value = FG.Graph.Fmt(top * step / GRID_STEPS)
		label:SetText(step == GRID_STEPS and FG.L("AXIS_FPS", value) or value)
		label:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
		label:ClearAnchors()
		label:SetAnchor(RIGHT, panel.plot, TOPLEFT, -6, step == GRID_STEPS and font_size / 2 or y)
		label:SetHidden(false)
		if ping_top and step > 0 then
			local p = AxisLabel(panel, "p_labels", step)
			p:SetColor(PING_COLOR[1], PING_COLOR[2], PING_COLOR[3], 0.85)
			local ms = FG.Graph.Fmt(ping_top * step / GRID_STEPS)
			p:SetText(step == GRID_STEPS and FG.L("PING_SCALE", ping_top) or ms)
			p:ClearAnchors()
			p:SetAnchor(LEFT, panel.plot, TOPRIGHT, 4, step == GRID_STEPS and font_size / 2 or y)
			p:SetHidden(false)
		end
	end
end

local function DrawTicks(panel, run, w)
	local seconds = Length(run)
	local from_s, to_s = view_from * seconds, view_to * seconds
	local span = max(to_s - from_s, 1e-6)
	local step = T.TickStep(span)
	local count = 0
	local t = ceil(from_s / step - 1e-9) * step
	while t <= to_s + 1e-6 do
		count = count + 1
		local label = AxisLabel(panel, "x_labels", count)
		label:SetText(FG.FormatDuration(t))
		label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
		label:ClearAnchors()
		label:SetAnchor(TOP, panel.plot, BOTTOMLEFT, (t - from_s) / span * w, 2)
		label:SetHidden(false)
		t = t + step
	end
end

local function DrawBars(panel, index, run, top, w, h, ping_top)
	local target = run.target_fps or Saved().target_fps
	local slices = panel.slices
	local col_w = w / max(#slices, 1)
	local G = FG.Graph
	for i, slice in ipairs(slices) do
		local color = (G.Dropped(slice.low, target) or G.Dropped(slice.fps, target)) and G.BAD or G.GOOD
		local low_h = max(1, min(h, h * slice.low / top))
		local fps_h = max(low_h, min(h, h * slice.fps / top))
		local bar = Pool(panel, "bars", "Bar", i)
		bar:ClearAnchors()
		bar:SetAnchor(BOTTOMLEFT, panel.plot, BOTTOMLEFT, (i - 1) * col_w, 0)
		bar:SetDimensions(max(1, col_w - 1), low_h)
		Paint(bar, color, 1)
		bar:SetHidden(false)
		local range = Pool(panel, "ranges", "Range", i)
		range:ClearAnchors()
		range:SetAnchor(BOTTOMLEFT, bar, TOPLEFT, 0, 0)
		range:SetDimensions(max(1, col_w - 1), max(1, fps_h - low_h))
		Paint(range, color, RANGE_ALPHA)
		range:SetHidden(fps_h - low_h < 1)
		local dot = Pool(panel, "dots", "Ping", i)
		if slice.ping and ping_top then
			dot:SetDimensions(DOT, DOT)
			dot:SetDrawLevel(4)
			dot:ClearAnchors()
			dot:SetAnchor(CENTER, bar, BOTTOM, 0, -h * min(1, slice.ping / ping_top))
			Paint(dot, G.PingHigh(slice.ping, run.ping_warn or Saved().ping_warn_ms) and G.BAD or PING_COLOR, 1)
			dot:SetHidden(false)
		else
			dot:SetHidden(true)
		end
		local area = HitArea(panel, index, i)
		area:ClearAnchors()
		area:SetAnchor(TOPLEFT, panel.plot, TOPLEFT, (i - 1) * col_w, 0)
		area:SetDimensions(max(1, col_w), h)
		area:SetHidden(false)
	end
	local ty = min(h, h * target / top)
	panel.target:ClearAnchors()
	panel.target:SetAnchor(LEFT, panel.plot, BOTTOMLEFT, 0, -ty)
	panel.target:SetAnchor(RIGHT, panel.plot, BOTTOMRIGHT, 0, -ty)
end

local function DrawMarks(panel, run, w, h)
	local seconds = Length(run)
	local from_s, to_s = view_from * seconds, view_to * seconds
	local span = max(to_s - from_s, 1e-6)
	local count = 0
	for _, event in ipairs(run.events or {}) do
		if event.at >= from_s and event.at <= to_s then
			count = count + 1
			local mark = Pool(panel, "marks", "Mark", count)
			mark:ClearAnchors()
			mark:SetAnchor(TOPLEFT, panel.plot, TOPLEFT, min(w - MARK_W, (event.at - from_s) / span * w), 0)
			mark:SetDimensions(MARK_W, h)
			mark:SetDrawLevel(5)
			Paint(mark, event.k == "reload" and RELOAD_COLOR or LOAD_COLOR, 0.9)
			mark:SetHidden(false)
		end
	end
	return count
end

local function Sets()
	local sets = {}
	local shown = T.Source()
	local fps = shown and FG.Lists(shown).fps
	if fps and #fps > 0 then sets[1] = { run = shown, name = FG.Summary.SourceName(FG.view.show) } end
	local cmp = FG.view.compare
	fps = cmp and FG.Lists(cmp).fps
	if sets[1] and fps and #fps > 0 then sets[2] = { run = cmp, name = FG.Summary.SourceName(cmp) } end
	return sets
end

local function Draw()
	if not built or win:IsHidden() then return false end
	local w, h = win:GetWidth(), win:GetHeight()
	font_size = zo_clamp(zo_round(BASE_FONT * w / 760), MIN_FONT, MAX_FONT)
	title:SetFont(Font())
	detail:SetFont(Font())
	empty:SetFont(Font())

	local key = tostring(FG.view.show) .. "|" .. tostring(FG.view.compare)
	if key ~= view_key then
		view_key = key
		view_from, view_to = 0, 1
		cursor, cursor_slot = nil, nil
	end
	local sets = Sets()
	for index = 1, 2 do HidePanel(Panel(index)) end
	empty:SetHidden(#sets > 0)
	if #sets == 0 then
		empty:SetText(FG.L("NOTHING_MEASURED_YET"))
		detail.fg_default = ""
		detail:SetText("")
		return true
	end
	min_span = max(MIN_SPAN, 2 / max(#FG.Lists(sets[1].run).fps, 2))
	if view_to - view_from < min_span - 1e-9 then view_from, view_to = 0, 1 end

	local top_y = HEADER_H + PAD / 2 + font_size + 8
	local name_h = font_size + 6
	local axis_h = font_size + 6
	local each = (h - top_y - PAD) / #sets
	local show_ping = Saved().show_ping
	local axis_w = max(AXIS_W, TextWidth(FG.L("AXIS_FPS", "999")) + 10)
	local ping_w = show_ping and max(PING_W, TextWidth(FG.L("PING_SCALE", 9999)) + 8) or 0
	local plot_w = max(1, w - PAD * 2 - axis_w - ping_w)
	local plot_h = max(20, each - name_h - axis_h)

	local fps_values, pings, count, ping_count = {}, {}, 0, 0
	for index, set in ipairs(sets) do
		local panel = Panel(index)
		panel.slices = T.Slices(set.run, view_from, view_to, MAX_SLICES)
		for _, slice in ipairs(panel.slices) do
			count = count + 1
			fps_values[count] = slice.fps
			if slice.ping then
				ping_count = ping_count + 1
				pings[ping_count] = slice.ping
			end
		end
	end
	local top = FG.Graph.Top(fps_values, count, Saved().target_fps, Saved().top_fps)
	local ping_top = show_ping and ping_count > 0 and FG.Graph.PingTop(pings, 1, ping_count, Saved().ping_warn_ms) or nil

	for index, set in ipairs(sets) do
		local panel = Panel(index)
		local y = top_y + (index - 1) * each
		panel.name:SetFont(Font())
		panel.name:SetText(set.name)
		panel.name:ClearAnchors()
		panel.name:SetAnchor(TOPLEFT, win, TOPLEFT, PAD + axis_w, y)
		panel.name:SetWidth(plot_w)
		panel.name:SetHidden(false)
		panel.plot:ClearAnchors()
		panel.plot:SetAnchor(TOPLEFT, win, TOPLEFT, PAD + axis_w, y + name_h)
		panel.plot:SetDimensions(plot_w, plot_h)
		panel.plot:SetHidden(false)
		DrawGrid(panel, top, plot_w, plot_h, ping_top)
		DrawBars(panel, index, set.run, top, plot_w, plot_h, ping_top)
		DrawMarks(panel, set.run, plot_w, plot_h)
		DrawTicks(panel, set.run, plot_w)
	end
	detail.fg_default = DefaultDetail()
	detail:SetText(detail.fg_default)
	PlaceCursor(true)
	return true
end
T.Draw = Draw

local function PlaceDefault(control)
	control:ClearAnchors()
	control:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
end

local function SaveSize()
	Saved().timeline_w, Saved().timeline_h = floor(win:GetWidth() + 0.5), floor(win:GetHeight() + 0.5)
end

local function Build()
	if built then return win end
	built = true
	win = WINDOW_MANAGER:CreateTopLevelWindow(NAME)
	win:SetClampedToScreen(true)
	win:SetMouseEnabled(true)
	win:SetMovable(true)
	win:SetHidden(true)
	win:SetDrawTier(DT_HIGH)
	LibAPH.ApplyPanelBackdrop(win, NAME .. "BG", THEME.BG_HUD)
	local header = LibAPH.CreateHeaderStrip(win, NAME .. "Header", HEADER_H)
	Paint(header, TITLE_BAR)
	title = Label(win, "Title")
	title:SetText("|c" .. THEME.TITLE_HEX .. "APH-FPSGraph|r  " .. FG.L("TIMELINE"))
	title:SetAnchor(LEFT, win, TOPLEFT, PAD, HEADER_H / 2)
	local close = LibAPH.CreateThemedCloseButton(win, NAME .. "Close", function() T.Hide() end, PAD / 2, 3)

	local function HeaderButton(suffix, text, right_of, onClick)
		local btn = WINDOW_MANAGER:CreateControlFromVirtual(NAME .. suffix, win, "ZO_DefaultButton")
		btn:SetDimensions(BTN_W, 24)
		btn:SetFont(IsPad() and "ZoFontGamepad18" or "ZoFontGameSmall")
		btn:SetText(text)
		btn:SetAnchor(RIGHT, right_of, LEFT, right_of == close and -10 or -6, 0)
		btn:SetHandler("OnClicked", onClick)
		return btn
	end
	local full = HeaderButton("ZoomFull", FG.L("ZOOM_FULL"), close, function() T.ResetZoom() end)
	local zoom_out = HeaderButton("ZoomOut", FG.L("ZOOM_OUT"), full, function() T.ZoomOut() end)
	local zoom_in = HeaderButton("ZoomIn", FG.L("ZOOM_IN"), zoom_out, function() T.ZoomIn() end)
	LibAPH.FitButtonRow(win, { zoom_in, zoom_out, full }, {
		gap = 6,
		font = IsPad() and "ZoFontGamepad18" or "ZoFontGameSmall",
		room = function() return win:GetWidth() - PAD - title:GetTextWidth() - 20 - close:GetWidth() - 10 - PAD / 2 end,
	})

	detail = Label(win, "Detail", THEME.MUTED)
	detail:SetAnchor(TOPLEFT, win, TOPLEFT, PAD, HEADER_H + PAD / 2)
	detail:SetAnchor(TOPRIGHT, win, TOPRIGHT, -PAD, HEADER_H + PAD / 2)
	empty = Label(win, "Empty")
	empty:SetAnchor(CENTER, win, CENTER, 0, 0)
	for index = 1, 2 do Panel(index) end

	win:SetHandler("OnMouseUp", function(_, button, upInside)
		if upInside and button == MOUSE_BUTTON_INDEX_RIGHT then FG.Graph.OpenMenu(win) end
	end)
	LibAPH.MakeWindowResizable(win, {
		handleSize = 8,
		minWidth = MIN_W, minHeight = MIN_H, maxWidth = MAX_W, maxHeight = MAX_H,
		onResizing = function()
			Draw()
			if FG.Pad then FG.Pad.Refresh() end
		end,
		onResizeStop = function()
			SaveSize()
			Draw()
			if FG.Pad then FG.Pad.Refresh() end
		end,
	})
	mover = LibAPH.CreateGamepadMover(win)
	position = LibAPH.CreateWindowPosition(win, {
		get = function() return Saved().timeline_x, Saved().timeline_y, Saved().timeline_point end,
		set = function(x, y, point) Saved().timeline_x, Saved().timeline_y, Saved().timeline_point = x, y, point end,
		placeDefault = PlaceDefault,
		mover = mover,
	})
	win:SetHandler("OnMoveStop", function() position:Save() end)
	mover:RegisterCallback(FG.name .. "_TimelineMove", 2, function()
		position:Save()
		if FG.Pad then FG.Pad.Refresh() end
	end)
	resizer = LibAPH.CreateGamepadResizer(win, {
		minWidth = MIN_W, minHeight = MIN_H,
		onResizing = function()
			SaveSize()
			Draw()
			if FG.Pad then FG.Pad.Refresh() end
		end,
		onResizeStop = function()
			if FG.Pad then FG.Pad.Refresh() end
		end,
	})
	sticky = LibAPH.CreateStickyFragment(win, { "hud", "hudui" })
	return win
end

function T.Show()
	Build()
	local s = Saved()
	win:SetDimensions(zo_clamp(s.timeline_w or 760, MIN_W, MAX_W), zo_clamp(s.timeline_h or 380, MIN_H, MAX_H))
	position:Apply()
	sticky:Open()
	Draw()
	if FG.Pad then FG.Pad.Opened("timeline") end
	return true
end

function T.Hide()
	if not built then return false end
	StopDrag()
	if FG.Pad and FG.Pad.StopHold then FG.Pad.StopHold() end
	sticky:Close()
	mover:ToggleGamepadMove(false)
	resizer:ToggleGamepadResize(false)
	if FG.Pad then FG.Pad.Refresh() end
	return true
end

function T.IsShown() return built and sticky:IsOpen() end

function T.Toggle()
	if T.IsShown() then return T.Hide() end
	return T.Show()
end

function T.Refresh()
	return Draw()
end

function T.OnBucket()
	if FG.view.show == nil and not T.IsZoomed() then Draw() end
end

function T.Window() return win end
function T.Mover() return mover end
function T.Resizer() return resizer end

function T.ResetPosition()
	if not built then return false end
	position:Reset()
	return true
end
