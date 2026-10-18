--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

local FG = APHFPSGraphCore
local Graph = {}
FG.Graph = Graph

local floor, max, min = math.floor, math.max, math.min
local THEME = LibAPH.THEME

local NAME = "APHFPSGraphWindow"
local TEXT_LEVEL = 10
local HEADER_H = 24
local PAD = 8
local AXIS_W = 46
local BASE_FONT = 13
local MIN_FONT, MAX_FONT = 10, 24
local FONT_BASE_W, FONT_BASE_H = 360, 230
local LINE_GAP = 2
local STAT_LINES = 4
local STATS_MS = 1000
local MIN_W, MIN_H = 240, 140
local MAX_W, MAX_H = 1200, 700
local PING_STEPS = { 100, 150, 200, 250, 300, 400, 500, 750, 1000, 1500, 2000, 3000 }
local DOT = 3
local GRID_STEPS = { 0.25, 0.5, 0.75 }
local TIME_STEPS = { 0, 0.25, 0.5, 0.75, 1 }
local DROP_FPS = 0.5
local FONT_FACE = IsConsoleUI() and "$(GAMEPAD_MEDIUM_FONT)" or "$(BOLD_FONT)"
local FONT_STYLE = "soft-shadow-thin"
local GOOD = { 0.61, 0.82, 0.3 }
local BAD = { 1, 0.25, 0.25 }
local PING_COLOR = { 0.35, 0.9, 0.95 }
local TITLE_BAR = { 0, 0, 0, 0.92 }
local RANGE_ALPHA = 0.4
local LOSS_HEX = "8C8C8C"
local MIN_VIEW = 8
local ZOOM_STEP = 0.5
local WHEEL_STEP = 0.8
local PAN_STEP = 0.25
local EDGE_MARGIN = 16
local DETAIL_FULL = 4
local PRESETS = {
	top_left = { TOPLEFT, TOPLEFT, 1, 1 },
	top_center = { TOP, TOP, 0, 1 },
	top_right = { TOPRIGHT, TOPRIGHT, -1, 1 },
	bottom_left = { BOTTOMLEFT, BOTTOMLEFT, 1, -1 },
	bottom_center = { BOTTOM, BOTTOM, 0, -1 },
	bottom_right = { BOTTOMRIGHT, BOTTOMRIGHT, -1, -1 },
}
Graph.PRESETS = PRESETS

Graph.MIN_W, Graph.MIN_H, Graph.HEADER_H = MIN_W, MIN_H, HEADER_H

local win, backdrop, header, title, rec_label, close_btn, plot, texts, sticky, position, mover, resizer
local stat_labels, axis_labels, time_labels, grid_lines = {}, {}, {}, {}
local bars, ranges, dots = {}, {}, {}
local target_line, target_label, ping_label, warn_line
local ping_labels = {}
local axis_w, ping_w = AXIS_W, 0
local built = false
local font_size = BASE_FONT
local plot_w, plot_h = 0, 0
local stat_lines, axis_key = {}, {}
local stats_at = 0
local column_count = 0
local in_scenes = true
local view_span, view_back = nil, 0
local drag

local function Saved() return FG.saved end

local function Paint(control, color, alpha)
	local a = alpha or color[4] or 1
	if control.fg_color == color and control.fg_alpha == a then return end
	control.fg_color, control.fg_alpha = color, a
	control:SetColor(color[1], color[2], color[3], a)
end

local function Show(control, shown)
	local hidden = not shown
	if control.fg_hidden == hidden then return end
	control.fg_hidden = hidden
	control:SetHidden(hidden)
end

local function Height(control, h)
	if control.fg_h == h then return end
	control.fg_h = h
	control:SetHeight(h)
end

local function Hex(color)
	return string.format("%02X%02X%02X", floor(color[1] * 255 + 0.5), floor(color[2] * 255 + 0.5), floor(color[3] * 255 + 0.5))
end

local function Font()
	return FONT_FACE .. "|" .. font_size .. "|" .. FONT_STYLE
end

local function ShowsGraph() return Saved().show_graph ~= false end

function Graph.FontSize() return font_size end

function Graph.Dropped(fps, target)
	return fps < target - DROP_FPS
end

function Graph.ColorFor(fps, target)
	if Graph.Dropped(fps, target) then return BAD end
	return GOOD
end

local function FrameDropped(ms, target)
	return ms > 1000 / (target - DROP_FPS)
end

function Graph.TopStep(value)
	if value <= 120 then return 30 end
	if value <= 300 then return 60 end
	return 120
end

function Graph.Top(list, count, target, fixed, extra, extra_count)
	if fixed and fixed > 0 then return fixed end
	local top = target
	for i = 1, count do if list[i] > top then top = list[i] end end
	if extra then for i = 1, extra_count do if extra[i] > top then top = extra[i] end end end
	local step = Graph.TopStep(top * 1.1)
	return max(step, math.ceil(top * 1.1 / step) * step)
end

local function Label(parent, suffix)
	local label = WINDOW_MANAGER:CreateControl(NAME .. suffix, parent, CT_LABEL)
	label:SetFont(Font())
	Paint(label, THEME.TEXT)
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

local function Columns()
	local s = Saved()
	return min(FG.Sampler.MAX_COLUMNS, max(1, floor(s.graph_seconds * 1000 / s.bucket_ms + 0.5)))
end

local function EnsureColumns(count)
	for i = #bars + 1, count do
		bars[i] = Texture(plot, NAME .. "Bar" .. i)
		ranges[i] = Texture(plot, NAME .. "Range" .. i)
		dots[i] = Texture(plot, NAME .. "Ping" .. i)
		dots[i]:SetDimensions(DOT, DOT)
	end
end

local function Detail()
	return Saved().detail_level or DETAIL_FULL
end

local function StatCount()
	local s = Saved()
	local detail = Detail()
	if detail <= 2 then return 1 end
	if detail == 3 then return 1 + (s.show_frametime and 1 or 0) end
	return 2 + (s.show_frametime and 1 or 0) + (s.show_ping and 1 or 0)
end

local function StatHeight()
	return StatCount() * (font_size + LINE_GAP)
end

function Graph.PingTop(list, first, last, warn)
	local high = warn or 0
	for i = first, last do
		local p = list[i]
		if p and p > high then high = p end
	end
	high = high * 1.1
	for _, step in ipairs(PING_STEPS) do
		if step >= high then return step end
	end
	return PING_STEPS[#PING_STEPS]
end

function Graph.PingHigh(ping, warn)
	return warn ~= nil and ping > warn
end

local function HideColumns(from)
	for i = from, #bars do
		Show(bars[i], false)
		Show(ranges[i], false)
		Show(dots[i], false)
	end
end

local function Mode()
	if not ShowsGraph() then return "text" end
	return "graph"
end

function Graph.FontSizeFor(w, h)
	if not ShowsGraph() then h = Saved().height end
	local scale = min(w / FONT_BASE_W, h / FONT_BASE_H)
	return zo_clamp(zo_round(BASE_FONT * scale), MIN_FONT, MAX_FONT)
end

Graph.TextSide = LibAPH.GetScreenThirdAlignAt

local function TextAlign(text_only)
	if not text_only then return TEXT_ALIGN_LEFT end
	return LibAPH.GetScreenThirdAlign(win)
end

local function PlaceTitle(align)
	title:ClearAnchors()
	rec_label:ClearAnchors()
	if align == TEXT_ALIGN_RIGHT then
		title:SetAnchor(RIGHT, win, TOPRIGHT, -PAD - HEADER_H, HEADER_H / 2)
		rec_label:SetAnchor(RIGHT, title, LEFT, -8, 0)
	elseif align == TEXT_ALIGN_CENTER then
		title:SetAnchor(CENTER, win, TOP, 0, HEADER_H / 2)
		rec_label:SetAnchor(LEFT, title, RIGHT, 8, 0)
	else
		title:SetAnchor(LEFT, win, TOPLEFT, PAD, HEADER_H / 2)
		rec_label:SetAnchor(LEFT, title, RIGHT, 8, 0)
	end
end

local labels_back, labels_span, labels_step

function Graph.ForgetTimeLabels()
	labels_back, labels_span, labels_step = nil, nil, nil
end

local function Layout()
	labels_back = nil
	axis_key.top = nil
	if not built then return end
	local w, h = win:GetWidth(), win:GetHeight()
	font_size = Graph.FontSizeFor(w, h)
	local font = Font()
	local mode = Mode()
	local text_only = mode == "text"
	local align = TextAlign(text_only)
	Graph.text_align = align
	PlaceTitle(align)

	local y = HEADER_H + PAD / 2
	for i, label in ipairs(stat_labels) do
		label:SetFont(font)
		label:SetHorizontalAlignment(align)
		label:ClearAnchors()
		label:SetAnchor(TOPLEFT, win, TOPLEFT, PAD, y + (i - 1) * (font_size + LINE_GAP))
		label:SetAnchor(TOPRIGHT, win, TOPRIGHT, -PAD, y + (i - 1) * (font_size + LINE_GAP))
	end
	local show_ping = Saved().show_ping and not text_only
	for _, label in ipairs(axis_labels) do label:SetFont(font) end
	ping_label:SetFont(font)
	axis_w = max(AXIS_W, floor(font_size * 3.6), math.ceil(axis_labels[1]:GetStringWidth(FG.L("AXIS_FPS", "9999")) / GetUIGlobalScale()) + 8)
	ping_w = show_ping and max(34, floor(font_size * 3.4), math.ceil(ping_label:GetStringWidth(FG.L("PING_SCALE", 9999)) / GetUIGlobalScale()) + 6) or 0
	for _, label in ipairs(axis_labels) do
		label:SetWidth(axis_w - 4)
		label:SetHidden(text_only)
	end
	for _, label in ipairs(ping_labels) do
		label:SetFont(font)
		label:SetWidth(max(1, ping_w - 3))
		label:SetHidden(not show_ping)
	end
	warn_line:SetHidden(not show_ping)
	for _, label in ipairs(time_labels) do label:SetFont(font) end
	target_label:SetFont(font)
	target_label:SetHidden(text_only)
	ping_label:SetWidth(max(1, ping_w - 3))
	ping_label:SetHidden(not show_ping)
	title:SetFont(font)
	rec_label:SetFont(font)

	local plot_top = y + StatHeight() + PAD / 2
	plot_w = max(1, w - PAD * 2 - axis_w - ping_w)
	plot_h = max(1, h - plot_top - PAD - font_size - LINE_GAP)
	plot:ClearAnchors()
	plot:SetAnchor(TOPLEFT, win, TOPLEFT, PAD + axis_w, plot_top)
	plot:SetDimensions(plot_w, plot_h)
	plot:SetHidden(text_only)

	column_count = Columns()
	EnsureColumns(column_count)
	local col_w = plot_w / column_count
	for i = 1, #bars do
		bars[i]:ClearAnchors()
		ranges[i]:ClearAnchors()
		if i <= column_count then
			local width = max(1, col_w - 1)
			bars[i]:SetAnchor(BOTTOMLEFT, plot, BOTTOMLEFT, (i - 1) * col_w, 0)
			bars[i]:SetWidth(width)
			ranges[i]:SetAnchor(BOTTOMLEFT, bars[i], TOPLEFT, 0, 0)
			ranges[i]:SetWidth(width)
		end
	end
	HideColumns(1)
	for i, share in ipairs(TIME_STEPS) do
		local label = time_labels[i]
		label:ClearAnchors()
		local point = (i == 1) and TOPLEFT or ((i == #TIME_STEPS) and TOPRIGHT or TOP)
		label:SetAnchor(point, plot, BOTTOMLEFT, plot_w * share, LINE_GAP)
		label:SetHidden(text_only)
	end
end
Graph.Layout = Layout

local function ApplyOpacity()
	if not built then return end
	local s = Saved()
	backdrop:SetAlpha(s.window_opacity)
	header:SetAlpha(s.window_opacity)
	plot:SetAlpha(s.graph_opacity)
	texts:SetAlpha(s.text_opacity)
	close_btn:SetAlpha(max(s.text_opacity, 0.2))
end
Graph.ApplyOpacity = ApplyOpacity

local function Fmt(value, digits)
	return string.format("%." .. (digits or 0) .. "f", value)
end

local function Tint(text, color)
	return "|c" .. Hex(color) .. text .. "|r"
end

function Graph.Loss(value, sign)
	return "|c" .. LOSS_HEX .. "(" .. sign .. Fmt(value, 2) .. ")|r"
end

function Graph.FpsText(value, target, loss)
	local text = Tint(Fmt(value), Graph.ColorFor(value, target))
	if loss and Graph.Dropped(value, target) then text = text .. " " .. Graph.Loss(target - value, "-") end
	return text
end

function Graph.MsText(value, target, loss)
	local dropped = FrameDropped(value, target)
	local text = Tint(Fmt(value, 1), dropped and BAD or GOOD)
	if loss and dropped then text = text .. " " .. Graph.Loss(value - 1000 / target, "+") end
	return text
end
Graph.Tint, Graph.Fmt, Graph.FrameDropped, Graph.GOOD, Graph.BAD = Tint, Fmt, FrameDropped, GOOD, BAD

function Graph.PingText(value, warn, loss)
	local high = Graph.PingHigh(value, warn)
	local text = Tint(Fmt(value), high and BAD or GOOD)
	if loss and high then text = text .. " " .. Graph.Loss(value - warn, "+") end
	return text
end

local function FpsText(value, target) return Graph.FpsText(value, target, true) end
local function MsText(value, target) return Graph.MsText(value, target, true) end

function Graph.MemoryText()
	local text = FG.L("LINE_MEMORY", Fmt(collectgarbage("count") / 1024, 1))
	local pool = GetTotalUserAddOnMemoryPoolUsageMB and GetTotalUserAddOnMemoryPoolUsageMB() or nil
	if pool then
		local cap = GetTotalUserAddOnMemoryPoolCapacityMB and GetTotalUserAddOnMemoryPoolCapacityMB() or 0
		if cap and cap > 0 then
			text = text .. "   " .. FG.L("LINE_POOL_OF", Fmt(pool, 1), Fmt(cap, 0))
		else
			text = text .. "   " .. FG.L("LINE_POOL", Fmt(pool, 1))
		end
	end
	return text
end

function Graph.StatLines(stats, s)
	local target = s.target_fps
	local detail = s.detail_level or DETAIL_FULL
	if detail <= 1 then return FG.L("LINE_FPS_SINGLE", FpsText(stats.current_fps, target)), "", "", "" end
	local line1 = FG.L("LINE_FPS", FpsText(stats.current_fps, target), FpsText(stats.avg_fps, target))
	if s.show_lows then line1 = line1 .. "   " .. FG.L("LINE_LOWS", FpsText(stats.low1_fps, target), FpsText(stats.low01_fps, target)) end
	if detail == 2 then return line1, "", "", "" end
	local line2 = ""
	if s.show_frametime then
		line2 = FG.L("LINE_FRAMETIME", MsText(stats.avg_ms, target), MsText(stats.p99_ms, target), MsText(stats.max_ms, target),
			Fmt(stats.jitter_ms, 1))
	end
	local line3 = ""
	if s.show_ping then
		local warn = s.ping_warn_ms
		line3 = FG.L("LINE_PING_FULL", Graph.PingText(stats.ping, warn, true), Graph.PingText(stats.ping_avg or 0, warn),
			Graph.PingText(stats.ping_min or 0, warn), Graph.PingText(stats.ping_max or 0, warn), Fmt(stats.ping_jitter or 0, 1))
	end
	if detail == 3 then return line1, line2, "", "" end
	local session = FG.Sampler.SessionStats()
	local parts = { FG.L("LINE_STUTTERS", session.stutters, s.stutter_ms) }
	if s.show_memory then parts[#parts + 1] = Graph.MemoryText() end
	return line1, line2, line3, table.concat(parts, "   ")
end

function Graph.RecText()
	if not FG.Sampler.IsRecording() then return "" end
	return Tint(FG.L("REC"), BAD) .. "  " .. FG.FormatDuration(FG.Sampler.RecordingSeconds())
end

local REC_LINE_NAME = "APHFPSGraphRecStatus"
local REC_LINE_ORDER = 3
local REC_LINE_TITLE = "|c9CD04CAPH-FPSGraph|r  "
local REC_LINE_JOB = "APHFPSGraph_RecStatus"
local REC_LINE_MS = 1000
local rec_line
local rec_ticking = false

local function RecLine()
	if rec_line == nil then
		rec_line = LibAPH.CreateStatusLine and LibAPH.CreateStatusLine(REC_LINE_NAME, {
			font = IsConsoleUI() and "ZoFontGamepad27" or "ZoFontGameMedium",
			width = IsConsoleUI() and 1100 or 900,
			align = TEXT_ALIGN_CENTER,
			point = TOP, relativeTo = "ZO_CompassFrame", relativePoint = BOTTOM,
			offsetX = 0, offsetY = 8, consoleOffsetX = 0, consoleOffsetY = 8,
			stack = "compass", order = REC_LINE_ORDER,
		}) or false
	end
	return rec_line or nil
end

function Graph.RecStatusOn()
	return Saved().rec_status ~= false and LibAPH.CreateStatusLine ~= nil
end

function Graph.RecStatusText()
	local text = REC_LINE_TITLE .. Graph.RecText()
	local limit = Saved().record_seconds or 0
	if limit > 0 then text = text .. " / " .. FG.FormatDuration(limit) end
	return text
end

function Graph.RefreshRecStatus()
	if FG.Sampler.IsRecording() and Graph.RecStatusOn() then
		RecLine():Set(Graph.RecStatusText())
		if not rec_ticking then
			rec_ticking = true
			EVENT_MANAGER:RegisterForUpdate(REC_LINE_JOB, REC_LINE_MS, Graph.RefreshRecStatus)
		end
		return true
	end
	if rec_ticking then
		rec_ticking = false
		EVENT_MANAGER:UnregisterForUpdate(REC_LINE_JOB)
	end
	if rec_line then rec_line:Hide() end
	return false
end

function Graph.GetRecStatusText()
	return rec_line and rec_line:GetText() or nil
end

local function DrawStats()
	stats_at = GetGameTimeMilliseconds() + STATS_MS
	LibAPH.SetTextIfChanged(rec_label, Graph.RecText())
	stat_lines[1], stat_lines[2], stat_lines[3], stat_lines[4] = Graph.StatLines(FG.Sampler.WindowStats(), Saved())
	local slot = 0
	for i = 1, STAT_LINES do
		if stat_lines[i] and stat_lines[i] ~= "" then
			slot = slot + 1
			if LibAPH.SetTextIfChanged(stat_labels[slot], stat_lines[i]) then
				LibAPH.FitLabelText(stat_labels[slot], stat_lines[i], { font = Font() })
			end
		end
	end
	for i = slot + 1, STAT_LINES do LibAPH.SetTextIfChanged(stat_labels[i], "") end
end

local function AxisChanged(top, s, show_ping, ping_top)
	local key = axis_key
	local warn = s.ping_warn_ms or 0
	if key.top == top and key.ping_top == ping_top and key.target == s.target_fps and key.show_ping == show_ping
		and key.warn == warn and key.plot_h == plot_h and key.font_size == font_size then
		return false
	end
	key.top, key.ping_top, key.target, key.show_ping, key.warn, key.plot_h, key.font_size = top, ping_top, s.target_fps, show_ping, warn, plot_h, font_size
	return true
end

local function DrawAxis(top, s, show_ping, ping_top)
	if not AxisChanged(top, s, show_ping, ping_top) then return end
	for i, share in ipairs(GRID_STEPS) do
		local y = plot_h * share
		grid_lines[i]:ClearAnchors()
		grid_lines[i]:SetAnchor(LEFT, plot, BOTTOMLEFT, 0, -y)
		grid_lines[i]:SetAnchor(RIGHT, plot, BOTTOMRIGHT, 0, -y)
		axis_labels[i]:ClearAnchors()
		axis_labels[i]:SetAnchor(RIGHT, plot, BOTTOMLEFT, -4, -y)
		axis_labels[i]:SetText(Fmt(top * share))
		ping_labels[i]:ClearAnchors()
		ping_labels[i]:SetAnchor(LEFT, plot, BOTTOMRIGHT, 3, -y)
		ping_labels[i]:SetText(Fmt((ping_top or 0) * share))
	end
	local top_label = axis_labels[#GRID_STEPS + 1]
	top_label:ClearAnchors()
	top_label:SetAnchor(RIGHT, plot, TOPLEFT, -4, font_size / 2)
	top_label:SetText(FG.L("AXIS_FPS", Fmt(top)))
	local ty = min(plot_h, plot_h * s.target_fps / top)
	target_line:ClearAnchors()
	target_line:SetAnchor(LEFT, plot, BOTTOMLEFT, 0, -ty)
	target_line:SetAnchor(RIGHT, plot, BOTTOMRIGHT, 0, -ty)
	target_label:ClearAnchors()
	target_label:SetAnchor(BOTTOMRIGHT, plot, BOTTOMRIGHT, -2, -ty - 1)
	target_label:SetText(FG.L("TARGET", s.target_fps))
	ping_label:SetHidden(not show_ping)
	ping_label:ClearAnchors()
	ping_label:SetAnchor(LEFT, plot, TOPRIGHT, 3, font_size / 2)
	ping_label:SetText(FG.L("PING_SCALE", ping_top or 0))
	local warn = s.ping_warn_ms or 0
	warn_line:SetHidden(not show_ping or not ping_top or warn >= ping_top)
	if show_ping and ping_top and warn < ping_top then
		local wy = plot_h * warn / ping_top
		warn_line:ClearAnchors()
		warn_line:SetAnchor(LEFT, plot, BOTTOMLEFT, 0, -wy)
		warn_line:SetAnchor(RIGHT, plot, BOTTOMRIGHT, 0, -wy)
	end
end
Graph.PING_COLOR = PING_COLOR

local function DrawColumn(i, fps, low, top, target, ping, ping_top, warn)
	local color = (Graph.Dropped(low, target) or Graph.Dropped(fps, target)) and BAD or GOOD
	local low_h = max(1, min(plot_h, plot_h * low / top))
	local fps_h = max(low_h, min(plot_h, plot_h * fps / top))
	Height(bars[i], low_h)
	Paint(bars[i], color, 1)
	Show(bars[i], true)
	local range = fps_h - low_h
	Show(ranges[i], range >= 1)
	if range >= 1 then
		Height(ranges[i], range)
		Paint(ranges[i], color, RANGE_ALPHA)
	end
	local dot = dots[i]
	if ping then
		local y = -plot_h * min(1, ping / ping_top)
		if dot.fg_y ~= y or dot.fg_bar ~= bars[i] then
			dot.fg_y, dot.fg_bar = y, bars[i]
			dot:ClearAnchors()
			dot:SetAnchor(CENTER, bars[i], BOTTOM, 0, y)
		end
		Paint(dot, Graph.PingHigh(ping, warn) and BAD or PING_COLOR, 1)
		Show(dot, true)
	else
		Show(dot, false)
	end
end

local function SetTimeLabels(texts_by_step)
	for i = 1, #TIME_STEPS do
		local label, text = time_labels[i], texts_by_step[i] or ""
		if label.fg_text ~= text then
			label.fg_text = text
			label:SetText(text)
		end
	end
end

local function ViewSpan()
	local full = max(1, column_count)
	local span = view_span or full
	return max(min(MIN_VIEW, full), min(full, span))
end

local function ClampView()
	local span = ViewSpan()
	view_span = span < column_count and span or nil
	view_back = max(0, min(view_back, column_count - span))
	if not view_span then view_back = 0 end
end

function Graph.IsZoomed() return view_span ~= nil or view_back > 0 end

function Graph.ViewRange()
	return ViewSpan(), view_back
end

local function Redraw()
	ClampView()
	Graph.Draw()
	return true
end

function Graph.Zoom(factor)
	local span = ViewSpan()
	local middle = view_back + span / 2
	local new_span = max(MIN_VIEW, floor(span * factor + 0.5))
	view_span = new_span
	view_back = view_back > 0 and floor(middle - new_span / 2 + 0.5) or 0
	return Redraw()
end

function Graph.Pan(share)
	view_back = view_back - floor(ViewSpan() * share + 0.5)
	return Redraw()
end

function Graph.ResetZoom()
	view_span, view_back = nil, 0
	return Redraw()
end

function Graph.ZoomIn() return Graph.Zoom(ZOOM_STEP) end
function Graph.ZoomOut() return Graph.Zoom(1 / ZOOM_STEP) end
function Graph.PanLeft() return Graph.Pan(-PAN_STEP) end
function Graph.PanRight() return Graph.Pan(PAN_STEP) end

local function DrawLive()
	local s = Saved()
	local columns = FG.Sampler.Columns()
	local top = Graph.Top(columns.fps, columns.count, s.target_fps, s.top_fps)
	local ping_top = Graph.PingTop(columns.ping, 1, columns.count, s.ping_warn_ms)
	DrawAxis(top, s, s.show_ping, ping_top)
	ClampView()
	local span = ViewSpan()
	local last = column_count - view_back
	local first_slot = column_count - columns.count
	for i = 1, column_count do
		local c = last - span + 1 + floor((i - 1) * span / column_count) - first_slot
		if c >= 1 and c <= columns.count then
			DrawColumn(i, columns.fps[c], columns.low[c], top, s.target_fps, s.show_ping and columns.ping[c] or nil, ping_top, s.ping_warn_ms)
		else
			Show(bars[i], false); Show(ranges[i], false); Show(dots[i], false)
		end
	end
	local step_s = s.bucket_ms / 1000
	if view_back ~= labels_back or span ~= labels_span or step_s ~= labels_step then
		labels_back, labels_span, labels_step = view_back, span, step_s
		local labels = {}
		for i, share in ipairs(TIME_STEPS) do
			local ago = floor((view_back + span * (1 - share)) * step_s + 0.5)
			labels[i] = ago == 0 and FG.L("NOW") or FG.L("SECONDS_AGO", ago)
		end
		SetTimeLabels(labels)
	end
end

local function StopDrag()
	drag = nil
	if plot then plot:SetHandler("OnUpdate", nil) end
end

local function OnDragUpdate()
	if not drag then return end
	local moved = floor((GetUIMousePosition() - drag.x) / max(drag.width, 1) * drag.span + 0.5)
	if moved ~= drag.moved then
		drag.moved = moved
		view_back = drag.back + moved
		Redraw()
	end
end

function Graph.Resample(list, count, use_min)
	local out, n = {}, #list
	if n == 0 then return out end
	for i = 1, count do
		local a = floor((i - 1) * n / count) + 1
		local b = max(a, floor(i * n / count))
		local v = use_min and math.huge or 0
		for k = a, b do
			if use_min then v = min(v, list[k]) else v = v + list[k] end
		end
		out[i] = use_min and v or v / (b - a + 1)
	end
	return out
end

function Graph.Draw(from_bucket)
	if not built or win:IsHidden() then return false end
	if not from_bucket or GetGameTimeMilliseconds() >= stats_at then DrawStats() end
	if Mode() == "graph" then DrawLive() end
	return true
end

function Graph.OnBucket()
	Graph.Draw(true)
	if FG.Summary then FG.Summary.OnBucket() end
	if FG.Timeline then FG.Timeline.OnBucket() end
end

local SavedRunChoices

local function RunChoices(current, pick, include_this)
	local out = {}
	if include_this then
		out[#out + 1] = { text = FG.L("THIS_RUN"), checked = current == nil, onClick = function() pick(nil) end }
	end
	local runs = FG.Runs()
	for i = #runs, 1, -1 do
		local run = runs[i]
		if include_this then
			out[#out + 1] = { text = FG.DescribeRun(run), checked = current == run, submenu = function() return SavedRunChoices(run) end }
		else
			out[#out + 1] = { text = FG.DescribeRun(run), checked = current == run, onClick = function() pick(run) end }
		end
	end
	return out
end

SavedRunChoices = function(run)
	return {
		{ text = FG.view.show == run and FG.L("SHOW_SHOWING_NOW") or FG.L("SHOW"), onClick = function() FG.SetShowing(run) end },
		{ text = FG.L("RENAME"), onClick = function() FG.AskRename(run) end },
		{
			text = FG.Danger(FG.L("DELETE")),
			onClick = function()
				FG.Confirm("APHFPSGraph_DeleteRun", FG.L("DELETE_RUN_TITLE"), FG.L("DELETE_RUN_BODY", FG.DescribeRun(run)), function() FG.DeleteRun(run) end)
			end,
		},
	}
end

function Graph.MenuEntries()
	local entries = {}
	local runs = FG.Runs()
	entries[#entries + 1] = { text = FG.L("RECORDING"), header = true }
	if FG.Sampler.IsRecording() then
		entries[#entries + 1] = { text = FG.L("STOP_RECORDING"), onClick = function() FG.StopRecording() end }
	else
		entries[#entries + 1] = { text = FG.L("START_RECORDING"), onClick = function() FG.StartRecording() end }
		entries[#entries + 1] = { text = FG.RecordLengthText(), onClick = function() FG.AskRecordLength() end }
		entries[#entries + 1] = {
			text = FG.L("MENU_RECORD_LOADS", FG.OnOff(Saved().record_loads)),
			onClick = function()
				Saved().record_loads = not Saved().record_loads
				FG.Apply()
			end,
		}
	end
	entries[#entries + 1] = { divider = true }
	entries[#entries + 1] = { text = FG.L("RESULTS"), header = true }
	entries[#entries + 1] = {
		text = FG.Summary.IsShown() and FG.L("HIDE_SUMMARY") or FG.L("SUMMARY"),
		onClick = function() FG.Summary.Toggle() end,
	}
	entries[#entries + 1] = {
		text = FG.Timeline.IsShown() and FG.L("HIDE_TIMELINE") or FG.L("TIMELINE"),
		onClick = function() FG.Timeline.Toggle() end,
	}
	entries[#entries + 1] = {
		text = FG.L("SHOWING") .. FG.DescribeRun(FG.view.show),
		submenu = function() return RunChoices(FG.view.show, FG.SetShowing, true) end,
	}
	entries[#entries + 1] = {
		text = FG.L("COMPARE_AGAINST") .. (FG.view.compare and FG.DescribeRun(FG.view.compare) or FG.L("NOTHING")),
		submenu = function()
			local choices = RunChoices(FG.view.compare, FG.SetCompare, false)
			table.insert(choices, 1, { text = FG.L("NOTHING"), checked = FG.view.compare == nil, onClick = function() FG.SetCompare(nil) end })
			return choices
		end,
	}
	if #runs > 0 then
		entries[#entries + 1] = {
			text = FG.L("SAVED_RECORDINGS"),
			submenu = function()
				local list = {}
				for i = #runs, 1, -1 do
					local run = runs[i]
					list[#list + 1] = {
						text = FG.DescribeRun(run) .. (FG.view.show == run and FG.L("SHOWING_TAG") or ""),
						submenu = function() return SavedRunChoices(run) end,
					}
				end
				return list
			end,
		}
	end
	if Graph.IsZoomed() then
		entries[#entries + 1] = { text = FG.L("ZOOM_FULL"), onClick = function() Graph.ResetZoom() end }
	end
	entries[#entries + 1] = { divider = true }
	entries[#entries + 1] = { text = FG.L("RESET_NUMBERS"), onClick = function() FG.ResetStats() end }
	if #runs > 0 then
		entries[#entries + 1] = {
			text = FG.Danger(FG.L("DELETE_LAST_RUN")),
			onClick = function()
				FG.Confirm("APHFPSGraph_DeleteLast", FG.L("DELETE_LAST_TITLE"), FG.L("WARN_DELETE_LAST_RUN"), function() FG.DeleteLastRun() end)
			end,
		}
		entries[#entries + 1] = {
			text = FG.Danger(FG.L("DELETE_ALL_RUNS")),
			onClick = function()
				FG.Confirm("APHFPSGraph_DeleteAll", FG.L("DELETE_ALL_TITLE"), FG.L("WARN_DELETE_ALL_RUNS"), function() FG.DeleteAllRuns() end)
			end,
		}
	end
	if LibAPH.SettingsMenuEntries and FG.SettingsControls then
		entries[#entries + 1] = { divider = true }
		entries[#entries + 1] = {
			text = FG.L("ADVANCED_OPTIONS"),
			submenu = function()
				return LibAPH.SettingsMenuEntries(FG.SettingsControls(), {
					id = "APHFPSGraph", rangeText = FG.L("SETTING_RANGE"), askText = FG.AskText, confirm = FG.Confirm,
				})
			end,
		}
	end
	return entries
end

function Graph.OpenMenu(owner)
	if not built then return false end
	LibAPH.ShowScrollableMenu(owner or win, Graph.MenuEntries(), { rebuild = Graph.MenuEntries })
	FG.PlaceMenu(owner or win)
	return true
end

local function PlaceDefault(control)
	control:ClearAnchors()
	control:SetAnchor(TOPRIGHT, GuiRoot, TOPRIGHT, -24, 140)
end

function Graph.ApplyScreenPosition()
	if not built then return false end
	local preset = PRESETS[Saved().screen_position or "custom"]
	if not preset then return false end
	win:ClearAnchors()
	win:SetAnchor(preset[1], GuiRoot, preset[2], preset[3] * EDGE_MARGIN, preset[4] * EDGE_MARGIN)
	position:Save()
	return true
end

local function Realign()
	if not built or Mode() ~= "text" then return end
	if TextAlign(true) ~= Graph.text_align then Layout() end
end
Graph.Realign = Realign

function Graph.WatchAlign()
	return position ~= nil and position:WatchMove()
end

function Graph.IsPinned()
	return PRESETS[Saved().screen_position or "custom"] ~= nil
end

local function Moved()
	Saved().screen_position = "custom"
	Layout()
end

local function SaveSize()
	local s = Saved()
	s.width, s.height = floor(win:GetWidth() + 0.5), floor(win:GetHeight() + 0.5)
end

local function TextHeight()
	return HEADER_H + PAD + StatHeight()
end

local function ApplySize()
	local s = Saved()
	local width = zo_clamp(s.width, MIN_W, MAX_W)
	if not ShowsGraph() then font_size = Graph.FontSizeFor(width, s.height) end
	local height = ShowsGraph() and s.height or TextHeight()
	win:SetDimensions(width, zo_clamp(height, ShowsGraph() and MIN_H or 20, MAX_H))
end

local function Build()
	if built then return win end
	built = true
	win = WINDOW_MANAGER:CreateTopLevelWindow(NAME)
	win:SetClampedToScreen(true)
	win:SetMouseEnabled(true)
	win:SetHidden(true)
	win:SetDrawTier(DT_HIGH)

	backdrop = LibAPH.ApplyPanelBackdrop(win, NAME .. "BG", THEME.BG_HUD)
	header = LibAPH.CreateHeaderStrip(win, NAME .. "Header", HEADER_H)
	Paint(header, TITLE_BAR)
	texts = WINDOW_MANAGER:CreateControl(NAME .. "Texts", win, CT_CONTROL)
	texts:SetAnchorFill(win)
	texts:SetMouseEnabled(false)
	title = Label(texts, "Title")
	title:SetText("|c" .. THEME.TITLE_HEX .. "APH-FPSGraph|r")
	title:SetAnchor(LEFT, win, TOPLEFT, PAD, HEADER_H / 2)
	title:SetMaxLineCount(1)
	rec_label = Label(texts, "Rec")
	rec_label:SetAnchor(LEFT, title, RIGHT, 8, 0)
	close_btn = LibAPH.CreateThemedCloseButton(win, NAME .. "Close", function()
		Saved().enabled = false
		FG.Apply()
	end, 4, 2)

	for i = 1, STAT_LINES do stat_labels[i] = Label(texts, "Stat" .. i) end

	plot = WINDOW_MANAGER:CreateControl(NAME .. "Plot", win, CT_CONTROL)
	plot:SetMouseEnabled(true)
	plot:SetHandler("OnMouseWheel", function(_, delta) Graph.Zoom(delta > 0 and WHEEL_STEP or 1 / WHEEL_STEP) end)
	plot:SetHandler("OnMouseDown", function(_, button)
		if button ~= MOUSE_BUTTON_INDEX_LEFT then return end
		drag = { x = GetUIMousePosition(), back = view_back, span = ViewSpan(), width = plot:GetWidth(), moved = 0 }
		plot:SetHandler("OnUpdate", OnDragUpdate)
	end)
	plot:SetHandler("OnMouseUp", function(_, button, upInside)
		StopDrag()
		if upInside and button == MOUSE_BUTTON_INDEX_RIGHT then Graph.OpenMenu() end
	end)
	local plot_bg = Texture(plot, NAME .. "PlotBG")
	plot_bg:SetAnchorFill(plot)
	Paint(plot_bg, THEME.INSET, 0.6)
	for i = 1, #GRID_STEPS do
		grid_lines[i] = Texture(plot, NAME .. "Grid" .. i)
		grid_lines[i]:SetHeight(1)
		Paint(grid_lines[i], THEME.STRIPE, 0.15)
	end
	for i = 1, #GRID_STEPS + 1 do
		axis_labels[i] = Label(texts, "Axis" .. i)
		axis_labels[i]:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
		Paint(axis_labels[i], THEME.MUTED)
	end
	for i = 1, #TIME_STEPS do
		time_labels[i] = Label(texts, "Time" .. i)
		Paint(time_labels[i], THEME.MUTED)
	end
	target_line = Texture(plot, NAME .. "Target")
	target_line:SetHeight(1)
	target_line:SetDrawLevel(3)
	Paint(target_line, THEME.ACCENT, 0.8)
	target_label = Label(texts, "TargetLabel")
	Paint(target_label, THEME.ACCENT)
	ping_label = Label(texts, "PingLabel")
	Paint(ping_label, PING_COLOR)
	for i = 1, #GRID_STEPS do
		ping_labels[i] = Label(texts, "PingAxis" .. i)
		Paint(ping_labels[i], PING_COLOR, 0.8)
	end
	warn_line = Texture(plot, NAME .. "PingWarn")
	warn_line:SetHeight(1)
	warn_line:SetDrawLevel(3)
	Paint(warn_line, PING_COLOR, 0.45)

	LibAPH.MakeWindowResizable(win, {
		handleSize = 8,
		minWidth = MIN_W, minHeight = MIN_H, maxWidth = MAX_W, maxHeight = MAX_H,
		onResizing = function()
			Layout()
			Graph.Draw()
			if FG.Pad then FG.Pad.Refresh() end
		end,
		onResizeStop = function()
			if ShowsGraph() then SaveSize() end
			Layout()
			Graph.Draw()
			if FG.Pad then FG.Pad.Refresh() end
		end,
	})
	win:SetHandler("OnMouseUp", function(_, button, upInside)
		if upInside and button == MOUSE_BUTTON_INDEX_RIGHT then Graph.OpenMenu() end
	end)
	if not IsConsoleUI() then
		close_btn:SetHidden(true)
		for _, control in ipairs({ win, plot, close_btn }) do
			ZO_PostHookHandler(control, "OnMouseEnter", function() close_btn:SetHidden(false) end)
			ZO_PostHookHandler(control, "OnMouseExit", function() close_btn:SetHidden(true) end)
		end
	end

	mover = LibAPH.CreateGamepadMover(win)
	position = LibAPH.CreateWindowPosition(win, {
		get = function() return Saved().x, Saved().y, Saved().point end,
		set = function(x, y, point) Saved().x, Saved().y, Saved().point = x, y, point end,
		placeDefault = PlaceDefault,
		mover = mover,
		onMoving = Realign,
		onMoveStop = Moved,
		onMoveEnd = function() if FG.Pad then FG.Pad.Refresh() end end,
	})
	resizer = LibAPH.CreateGamepadResizer(win, {
		minWidth = MIN_W, minHeight = MIN_H,
		onResizing = function()
			Layout()
			Graph.Draw()
			if FG.Pad then FG.Pad.Refresh() end
		end,
		onResizeStop = function()
			if ShowsGraph() then SaveSize() end
			if FG.Pad then FG.Pad.Refresh() end
		end,
	})

	sticky = LibAPH.CreateStickyFragment(win, { "hud", "hudui" })
	return win
end
Graph.Build = Build

local function ApplyScenes()
	local everywhere = Saved().everywhere
	if everywhere and in_scenes then
		LibAPH.RemoveFragmentFromScenes(sticky.fragment, { "hud", "hudui" })
		in_scenes = false
	elseif not everywhere and not in_scenes then
		LibAPH.AddFragmentToScenes(sticky.fragment, { "hud", "hudui" })
		in_scenes = true
	end
end

function Graph.Refresh()
	if not built then return false end
	local s = Saved()
	win:SetMovable(not s.locked and not Graph.IsPinned())
	win:SetResizeHandleSize((s.locked or not ShowsGraph()) and 0 or 8)
	ApplySize()
	position:Apply()
	Graph.ApplyScreenPosition()
	ApplyScenes()
	Layout()
	ApplyOpacity()
	Graph.Draw()
	return true
end

function Graph.Open()
	Build()
	local was_open = sticky:IsOpen()
	sticky:Open()
	Graph.Refresh()
	if FG.Pad and not was_open then FG.Pad.Opened("graph") end
	return true
end

function Graph.Close()
	if not built then return false end
	sticky:Close()
	return true
end

function Graph.IsOpen()
	return built and sticky:IsOpen()
end

function Graph.ResetPosition()
	if not built then return false end
	Saved().screen_position = "custom"
	position:Reset()
	Layout()
	return true
end

function Graph.StartMove()
	if not built then
		FG.saved.enabled = true
		FG.Apply()
	end
	if Graph.IsPinned() then return false end
	position:StartGamepadMove()
	return true
end

function Graph.Window() return win end
function Graph.Mover() return mover end
function Graph.Resizer() return resizer end
