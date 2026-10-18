--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

local APHP = APHProfilerCore
local TimelineBucketValue, TimelineColors, TimelineLegendTip, TimelineSliceText, TimelineSliceTip
local TimelineSlices, ToggleTimelineSeries

local WINDOW_NAME = "APHProfilerTimeline"
local TEXT_LEVEL = 10
local WIDTH_SHARE = 0.5
local HEIGHT_SHARE = 0.42
local COMPARE_HEIGHT_SHARE = 0.62
local MIN_WIDTH = 680
local MIN_HEIGHT = 360
local PAD = 12
local HEADER_H = 30
local DETAIL_H = 20
local LEGEND_ROW_H = 18
local LEGEND_COLUMNS = 4
local LEGEND_SAMPLE_W = 16
local PANEL_TITLE_H = 18
local PANEL_GAP = 12
local AXIS_W = 58
local AXIS_H = 20
local GRID_STEPS = 4
local LINE_T = 2
local LEADER_H = 4
local TICK_H = 4
local TOTAL = "__total"
local OTHER = APHP.TIMELINE_OTHER
local DRAW_LEVEL = 9100
local PANEL_PREFIX = { "", "Cmp" }
local TICK_STEPS = { 1, 2, 5, 10, 15, 30, 60, 120, 300, 600, 900, 1800 }
local TARGET_TICKS = 8
local MAX_DRAWN = 150
local SLICE_PX = 6
local PAD_TAP_PX = 4
local PAN_EDGE_SHARE = 0.1
local LEADER_GAP = 2
local AXIS_GAP = 6
local MIN_AXIS_W = 40
local TITLE_LINE_H, TITLE_LINE_H_PAD = 16, 24
local LEGEND_ROW_H_PAD = 24
local SCALE_STEPS = { 1, 1.2, 1.6, 2, 2.4, 3, 4, 5, 6, 8, 10 }
local LOG_DECADES_MAX = 5
local LOG_FLOOR_MS = 0.001
local LOG_LABEL_ROOM = 2
local MIN_SPAN = 0.01
local ZOOM_STEP = 0.5
local WHEEL_STEP = 0.8
local DETAIL_PIECES = 3
local ZOOM_BTN_W = 78
local SLICE_GAP = 6
local SLICE_HEAD_H = 22
local SLICE_KEY_W = 118
local SLICE_ROW_H, SLICE_ROW_H_PAD = 18, 26
local CLOSE_BTN_SIZE = LibAPH.THEME.CLOSE_SIZE

local GRID = { 1, 1, 1, 0.08 }
local AXIS_TEXT = { 0.62, 0.62, 0.66, 1 }
local TOTAL_COLOR = { 0.92, 0.92, 0.92 }
local OTHER_COLOR = { 0.45, 0.45, 0.45 }
local PALETTE = {
	{ 0.27, 0.72, 0.22 },
	{ 1, 0.5, 0.05 },
	{ 0.8, 0.9, 0.42 },
	{ 0.35, 0.68, 1 },
	{ 0.86, 0.42, 0.9 },
	{ 1, 0.82, 0.28 },
	{ 0.25, 0.85, 0.8 },
	{ 1, 0.4, 0.45 },
	{ 0.62, 0.52, 1 },
	{ 0.95, 0.65, 0.5 },
	{ 0.5, 0.95, 0.55 },
	{ 0.9, 0.9, 0.55 },
	{ 0.45, 0.55, 0.85 },
	{ 0.85, 0.6, 0.8 },
	{ 0.7, 0.8, 0.95 },
}

local function SeriesShown()
	return math.min(APHP.GetListLimit(), #PALETTE)
end

local win
local title_lbl
local detail_lbl
local empty_lbl
local panels = {}
local legend = {}
local shown_sources = {}
local shown_legend = {}
local pad_cursor
local view_from, view_to = 0, 1
local view_sources = {}
local min_span = MIN_SPAN
local drag
local shown_sets, shown_titles = {}, {}
local slice_box, slice_heads, slice_rows = nil, {}, {}
local slice_below = false

local function IsPad() return IsConsoleUI() or IsInGamepadPreferredMode() end

local function Font(size)
	if IsPad() then return "ZoFontGamepad18" end
	return string.format("$(MEDIUM_FONT)|%d|soft-shadow-thin", size or 14)
end

local function Label(name, parent, size, color)
	local lbl = WINDOW_MANAGER:CreateControl(name, parent, CT_LABEL)
	lbl:SetFont(Font(size))
	local c = color or { 0.85, 0.85, 0.85, 1 }
	lbl:SetColor(c[1], c[2], c[3], c[4] or 1)
	LibAPH.RaiseLabel(lbl, { level = TEXT_LEVEL, backdrop = false })
	return lbl
end

local function Rect(name, parent, color)
	local tex = WINDOW_MANAGER:CreateControl(name, parent, CT_TEXTURE)
	tex:SetMouseEnabled(false)
	tex:SetColor(color[1], color[2], color[3], color[4] or 1)
	return tex
end


local function ByValue(a, b)
	if a.value == b.value then return a.owner < b.owner end
	return a.value > b.value
end

local function Series(timeline)
	local totals = {}
	for owner, buckets in pairs(timeline.owners) do
		local sum = 0
		for _, ms in pairs(buckets) do sum = sum + ms end
		totals[#totals + 1] = { owner = owner, value = sum }
	end
	table.sort(totals, ByValue)

	local order, other = {}, {}
	for index, entry in ipairs(totals) do
		if index <= SeriesShown() then
			order[#order + 1] = { owner = entry.owner, ms = entry.value }
		else
			other[#other + 1] = entry.owner
		end
	end
	if #other > 0 then
		local sum = 0
		for index = SeriesShown() + 1, #totals do sum = sum + totals[index].value end
		order[#order + 1] = { owner = OTHER, ms = sum, members = other }
	end
	return order
end

function TimelineBucketValue(timeline, series, bucket)
	local frames = timeline.frames_in[bucket] or 0
	if frames <= 0 then return 0 end
	local ms = 0
	if series.members then
		for _, owner in ipairs(series.members) do ms = ms + ((timeline.owners[owner] or {})[bucket] or 0) end
	else
		ms = (timeline.owners[series.owner] or {})[bucket] or 0
	end
	return ms / frames
end

function APHP.TimelineStacks(timeline)
	local order = Series(timeline)
	local stacks, peak = {}, 0
	for bucket = 1, timeline.buckets do
		local stack, height = {}, 0
		for _, series in ipairs(order) do
			local value = TimelineBucketValue(timeline, series, bucket)
			stack[#stack + 1] = { owner = series.owner, value = value }
			height = height + value
		end
		stack.total = height
		stacks[bucket] = stack
		if height > peak then peak = height end
	end
	return stacks, peak, order
end

local function SessionBars(detail, timeline)
	local bars = {}
	for bucket = 1, timeline.buckets do
		local frames = timeline.frames_in[bucket] or 0
		local pieces, total = {}, 0
		if frames > 0 then
			for owner, series in pairs(timeline.owners) do
				local value = (series[bucket] or 0) / frames
				if value > 0 then
					pieces[#pieces + 1] = { owner = owner, value = value }
					total = total + value
				end
			end
		end
		table.sort(pieces, ByValue)
		bars[bucket] = { total = total, peak = timeline.worst_in[bucket] or 0, pieces = pieces, frames = frames }
	end
	return { buckets = timeline.buckets, bars = bars, worst = timeline.worst, stacked = true,
		frames = detail.frames or 0, elapsed_ms = detail.elapsed_ms or 0 }
end

local function SavedBars(detail, compact)
	local bars = {}
	for bucket = 1, compact.buckets do
		local total = compact.avg[bucket] or 0
		local owner, owned = compact.dominant[bucket], compact.dominant_avg[bucket] or 0
		local pieces, counted, listed = {}, 0, {}
		for name, values in pairs(compact.series or {}) do
			local value = values[bucket] or 0
			if value > 0 then
				pieces[#pieces + 1] = { owner = name, value = value }
				counted, listed[name] = counted + value, true
			end
		end
		if owner and owned > 0 and not listed[owner] then
			pieces[#pieces + 1] = { owner = owner, value = owned }
			counted = counted + owned
		end
		if total - counted > 1e-9 then pieces[#pieces + 1] = { owner = OTHER, value = total - counted } end
		table.sort(pieces, ByValue)
		bars[bucket] = { total = total, peak = compact.peak[bucket] or 0, pieces = pieces, leader = owner, frames = 1 }
	end
	return { buckets = compact.buckets, bars = bars, worst = compact.worst, stacked = false, series = compact.series or {},
		frames = detail.frames or 0, elapsed_ms = detail.elapsed_ms or 0 }
end

function APHP.TimelineBars(detail)
	if type(detail) ~= "table" then return nil end
	if detail.timeline and (detail.timeline.buckets or 0) > 0 then return SessionBars(detail, detail.timeline) end
	if detail.compact and (detail.compact.buckets or 0) > 0 then return SavedBars(detail, detail.compact) end
	return nil
end

function TimelineColors(bar_sets)
	local totals = {}
	for _, set in ipairs(bar_sets) do
		for _, bar in ipairs(set.bars) do
			for _, piece in ipairs(bar.pieces) do
				if piece.owner ~= OTHER then totals[piece.owner] = (totals[piece.owner] or 0) + piece.value end
			end
		end
	end
	local order = {}
	for owner, value in pairs(totals) do order[#order + 1] = { owner = owner, value = value } end
	table.sort(order, ByValue)

	local colors, legend_order = { [OTHER] = OTHER_COLOR, [TOTAL] = TOTAL_COLOR }, { TOTAL }
	for index = 1, math.min(#order, SeriesShown()) do
		colors[order[index].owner] = PALETTE[index]
		legend_order[#legend_order + 1] = order[index].owner
	end
	return colors, legend_order
end

function APHP.NiceCeiling(value)
	if not value or value <= 0 then return 0.001 end
	local magnitude = 10 ^ math.floor(math.log10(value))
	for _, step in ipairs(SCALE_STEPS) do
		if value <= step * magnitude + 1e-12 then return step * magnitude end
	end
	return 10 * magnitude
end

function APHP.TimeTickStep(seconds)
	for _, step in ipairs(TICK_STEPS) do
		if seconds / step <= TARGET_TICKS then return step end
	end
	return TICK_STEPS[#TICK_STEPS]
end

function APHP.FormatClock(seconds)
	local whole = math.floor(seconds + 0.5)
	return string.format("%02d:%02d", math.floor(whole / 60), whole % 60)
end

local function HiddenSeries()
	local hidden = APHP.saved.timeline_hidden
	if type(hidden) ~= "table" then
		hidden = {}
		APHP.saved.timeline_hidden = hidden
	end
	return hidden
end

function ToggleTimelineSeries(key)
	local hidden = HiddenSeries()
	hidden[key] = not hidden[key] or nil
	APHP.RefreshTimeline()
	return not hidden[key]
end

local function SeriesName(key)
	return key == TOTAL and APHP.L("TOTAL_ADD_ON_LUA") or LibAPH.StripColors(key)
end

function APHP.TimelineLegendEntries()
	local entries = {}
	for _, key in ipairs(shown_legend) do
		entries[#entries + 1] = {
			text = SeriesName(key), checkbox = true, checked = not HiddenSeries()[key],
			onToggle = function(on)
				if on == (HiddenSeries()[key] == true) then ToggleTimelineSeries(key) end
			end,
		}
	end
	return entries
end

local function SecondsAt(set, frame)
	if set.frames <= 0 then return 0 end
	return frame / set.frames * set.elapsed_ms / 1000
end

function APHP.TimelineAggregate(set, first, last)
	local weight, total, peak, by_owner = 0, 0, 0, {}
	for bucket = first, last do
		local bar = set.bars[bucket]
		if bar then
			local w = bar.frames or 1
			weight = weight + w
			total = total + bar.total * w
			if bar.peak > peak then peak = bar.peak end
			for _, piece in ipairs(bar.pieces) do
				by_owner[piece.owner] = (by_owner[piece.owner] or 0) + piece.value * w
			end
		end
	end
	local pieces, leader, leader_value = {}, nil, 0
	for owner, sum in pairs(by_owner) do
		local value = weight > 0 and sum / weight or 0
		pieces[#pieces + 1] = { owner = owner, value = value }
		if owner ~= OTHER and value > leader_value then leader, leader_value = owner, value end
	end
	table.sort(pieces, ByValue)
	local seconds = set.elapsed_ms / 1000
	return { total = weight > 0 and total / weight or 0, peak = peak, pieces = pieces, leader = leader, frames = weight,
		first = first, last = last, t0 = (first - 1) / set.buckets * seconds, t1 = last / set.buckets * seconds }
end

function TimelineSlices(set, from, to, most)
	local n = set.buckets
	local first = zo_clamp(math.floor(from * n + 1e-9) + 1, math.min(1, n), n)
	local last = zo_clamp(math.ceil(to * n - 1e-9), first, n)
	local count = last - first + 1
	local drawn = math.max(math.min(count, most or MAX_DRAWN, MAX_DRAWN), 1)
	local slices = {}
	for index = 1, drawn do
		local a = first + math.floor((index - 1) * count / drawn)
		local b = first + math.floor(index * count / drawn) - 1
		slices[index] = APHP.TimelineAggregate(set, a, math.max(a, b))
	end
	return slices
end

local function PieceName(owner)
	return owner == OTHER and APHP.L("OTHER_ADD_ONS") or LibAPH.StripColors(owner)
end

function TimelineSliceText(slice, pieces_shown)
	local parts = {}
	local limit = math.min(#slice.pieces, pieces_shown or #slice.pieces)
	for index = 1, limit do
		local piece = slice.pieces[index]
		parts[#parts + 1] = string.format("%s %s", PieceName(piece.owner), APHP.Format(piece.value))
	end
	local more = #slice.pieces - limit
	return string.format(APHP.L("PER_FRAME_HEAVIEST_FRAME"),
		APHP.FormatClock(slice.t0), APHP.FormatClock(slice.t1), APHP.Format(slice.total), APHP.Format(slice.peak),
		#parts > 0 and table.concat(parts, ", ") or APHP.L("NO_ADD_ON_LUA"), more > 0 and string.format(APHP.L("AND_MORE"), more) or "")
end

function TimelineSliceTip(slice, title)
	local lines = { "|cFFD700" .. APHP.FormatClock(slice.t0) .. " - " .. APHP.FormatClock(slice.t1) .. "|r" .. (title and ("  " .. title) or ""),
		string.format(APHP.L("PER_FRAME_HEAVIEST_FRAME_2"), APHP.Format(slice.total), APHP.Format(slice.peak)), "" }
	local limit = math.min(#slice.pieces, APHP.GetListLimit())
	for index = 1, limit do
		local piece = slice.pieces[index]
		lines[#lines + 1] = string.format("%s  %s", APHP.Format(piece.value), PieceName(piece.owner))
	end
	if #slice.pieces > limit then
		lines[#lines + 1] = string.format(APHP.L("MORE_ALL_SMALLER"), #slice.pieces - limit)
	end
	return table.concat(lines, "\n")
end

function APHP.SliceDetails(slice, set, panel_index, title)
	local top = slice.pieces[1]
	local owner = slice.leader or (top and top.owner)
	local name = owner and PieceName(owner) or APHP.L("NO_ADD_ON_LUA")
	local value = 0
	for _, piece in ipairs(slice.pieces) do
		if piece.owner == owner then value = piece.value end
	end
	local frame_from = math.floor((slice.first - 1) / set.buckets * set.frames) + 1
	local frame_to = math.max(frame_from, math.floor(slice.last / set.buckets * set.frames))
	local id = slice.first == slice.last and tostring(slice.first) or (slice.first .. "-" .. slice.last)
	local category = APHP.L("SLICE_CATEGORY_LUA")
	if not owner then category = APHP.L("NO_ADD_ON_LUA") elseif not slice.leader then category = APHP.L("OTHER_ADD_ONS") end
	local args = {
		{ "SLICE_ID_ARG", id },
		{ "SLICE_LOCATION", string.format(APHP.L("SLICE_FRAMES"), frame_from, frame_to) },
		{ "SLICE_NAME_ARG", owner and string.format(APHP.L("SLICE_PIECE"), name, APHP.Format(value)) or name },
		{ "SLICE_PARENT", title or "" },
	}
	local details = {
		{ "SLICE_NAME", name },
		{ "SLICE_CATEGORY", category },
		{ "SLICE_START_TIME", APHP.FormatClock(slice.t0) },
		{ "SLICE_DURATION", string.format(APHP.L("SLICE_SECONDS"), slice.t1 - slice.t0) },
		{ "SLICE_THREAD_DURATION", APHP.Format(slice.total * (slice.frames or 0)) },
		{ "SLICE_THREAD", APHP.L("SLICE_THREAD_UI") },
		{ "SLICE_PROCESS", APHP.L("SLICE_PROCESS_GAME") },
		{ "SLICE_SLICE_ID", string.format("%d:%s", panel_index, id) },
	}
	return args, details
end

function APHP.TimelineBucketText(detail, bucket)
	local set = APHP.TimelineBars(detail)
	if not set or not set.bars[bucket] then return "" end
	return TimelineSliceText(APHP.TimelineAggregate(set, bucket, bucket), DETAIL_PIECES)
end

function APHP.GetTimelineView() return view_from, view_to end

function APHP.SetTimelineView(from, to)
	local span = zo_clamp(to - from, min_span, math.max(1, min_span))
	if from < 0 then from = 0 end
	if from + span > 1 then from = 1 - span end
	view_from, view_to = from, from + span
	APHP.RefreshTimeline()
	return view_from, view_to
end

function APHP.ZoomTimeline(factor, center)
	local span = view_to - view_from
	center = center or (view_from + span / 2)
	local new_span = zo_clamp(span * factor, min_span, math.max(1, min_span))
	local ratio = span > 0 and (center - view_from) / span or 0.5
	return APHP.SetTimelineView(center - new_span * ratio, center - new_span * ratio + new_span)
end

function APHP.PanTimeline(amount)
	local span = view_to - view_from
	return APHP.SetTimelineView(view_from + span * amount, view_to + span * amount)
end

function APHP.ResetTimelineZoom()
	return APHP.SetTimelineView(0, 1)
end

function APHP.IsTimelineZoomed()
	return view_from > 1e-9 or view_to < 1 - 1e-9
end

local function WorstText(set)
	local worst = set.worst and set.worst[1]
	if not worst then return APHP.L("NO_ADD_ON_LUA_RAN") end
	return string.format(APHP.L("HEAVIEST_FRAME_AT_MOSTLY"), APHP.Format(worst.ms),
		APHP.FormatClock(SecondsAt(set, worst.frame)), LibAPH.StripColors(worst.owner or "?"))
end

local function DefaultDetail(sets)
	local hint = IsPad() and "" or APHP.L("WHEEL_TO_ZOOM_DRAG_TO_PAN")
	if #sets == 1 then
		local text = WorstText(sets[1])
		return text:sub(1, 1):upper() .. text:sub(2) .. "." .. hint
	end
	return string.format(APHP.L("SHOWN_COMPARED"), WorstText(sets[1]), WorstText(sets[2]), hint)
end

local function SeriesValue(set, key, bar)
	if key == TOTAL then return bar.total end
	if not set.stacked and not (set.series and set.series[key]) then return nil end
	for _, piece in ipairs(bar.pieces) do
		if piece.owner == key then return piece.value end
	end
	return 0
end

local function Pool(panel, kind, key)
	panel.pool[kind] = panel.pool[kind] or {}
	local pool = panel.pool[kind]
	local tex = pool[key]
	if not tex then
		tex = Rect(string.format("%s%s%s", panel.prefix, kind, key), panel.plot, GRID)
		pool[key] = tex
	end
	return tex
end

local function HidePool(panel)
	for _, pool in pairs(panel.pool) do
		for _, tex in pairs(pool) do tex:SetHidden(true) end
	end
end

local function SliceBox()
	if slice_box then return slice_box end
	slice_box = WINDOW_MANAGER:CreateControl(WINDOW_NAME .. "Slice", win, CT_CONTROL)
	slice_box:SetHidden(true)
	LibAPH.ApplyPanelBackdrop(slice_box, WINDOW_NAME .. "SliceBG", LibAPH.THEME.BG)
	for col = 1, 2 do
		slice_heads[col] = Label(WINDOW_NAME .. "SliceHead" .. col, slice_box, 13, { 1, 0.84, 0, 1 })
	end
	return slice_box
end

local function SliceRow(col, index)
	local key = col .. "_" .. index
	local row = slice_rows[key]
	if row then return row end
	row = { key = Label(WINDOW_NAME .. "SliceKey" .. key, slice_box, 12, AXIS_TEXT), value = Label(WINDOW_NAME .. "SliceValue" .. key, slice_box, 12) }
	row.value:SetMaxLineCount(1)
	row.value:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
	slice_rows[key] = row
	return row
end

local function FillColumn(col, heading, list, x, width, row_h)
	local head = slice_heads[col]
	head:SetText(heading)
	head:ClearAnchors()
	head:SetAnchor(TOPLEFT, slice_box, TOPLEFT, x, PAD / 2)
	for index = 1, math.max(#list, 8) do
		local row = SliceRow(col, index)
		local pair = list[index]
		row.key:SetHidden(pair == nil)
		row.value:SetHidden(pair == nil)
		if pair then
			local y = PAD / 2 + SLICE_HEAD_H + (index - 1) * row_h
			row.key:ClearAnchors()
			row.key:SetAnchor(TOPLEFT, slice_box, TOPLEFT, x, y)
			row.key:SetWidth(SLICE_KEY_W)
			LibAPH.FitLabelText(row.key, APHP.L(pair[1]), { font = Font(12) })
			row.value:ClearAnchors()
			row.value:SetAnchor(TOPLEFT, slice_box, TOPLEFT, x + SLICE_KEY_W, y)
			row.value:SetWidth(math.max(width - SLICE_KEY_W, 1))
			LibAPH.FitLabelText(row.value, pair[2], { font = Font(12) })
		end
	end
end

local function HideSlice()
	if not slice_box or slice_box:IsHidden() then return end
	slice_box:SetHidden(true)
	slice_below = false
	if APHP.OnPadStickStopped then APHP.OnPadStickStopped() end
end

local function ShowSlice(panel_index, slot)
	local panel = panels[panel_index]
	local slice = panel and panel.slices and panel.slices[slot]
	local set = shown_sets[panel_index]
	if not slice or not set then return HideSlice() end
	local args, details = APHP.SliceDetails(slice, set, panel_index, shown_titles[panel_index])
	SliceBox()
	local row_h = IsPad() and SLICE_ROW_H_PAD or SLICE_ROW_H
	local w = win:GetWidth()
	local col_w = (w - PAD * 3) / 2
	FillColumn(1, APHP.L("SLICE_ARGUMENTS"), args, PAD, col_w, row_h)
	FillColumn(2, APHP.L("SLICE_DETAILS"), details, PAD * 2 + col_w, col_w, row_h)
	local h = PAD + SLICE_HEAD_H + #details * row_h
	slice_box:SetDimensions(w, h)
	slice_box:ClearAnchors()
	slice_below = win:GetBottom() + SLICE_GAP + h <= GuiRoot:GetHeight()
	if slice_below then
		slice_box:SetAnchor(TOPLEFT, win, BOTTOMLEFT, 0, SLICE_GAP)
	else
		slice_box:SetAnchor(BOTTOMLEFT, win, TOPLEFT, 0, -SLICE_GAP)
	end
	slice_box:SetHidden(false)
	if APHP.OnPadStickStopped then APHP.OnPadStickStopped() end
end
APHP.ShowTimelineSlice = ShowSlice

function APHP.GetTimelineDock()
	if slice_box and slice_below and not slice_box:IsHidden() then return slice_box end
	return nil
end

local function CrosshairAt(panel, x)
	panel.crosshair:ClearAnchors()
	panel.crosshair:SetAnchor(TOPLEFT, panel.plot, TOPLEFT, zo_clamp(x, 0, math.max(panel.plot:GetWidth() - 1, 0)), 0)
	panel.crosshair:SetDimensions(1, panel.plot:GetHeight())
	panel.crosshair:SetHidden(false)
end

local function Crosshair(panel, slot)
	CrosshairAt(panel, (slot - 0.5) * panel.plot:GetWidth() / #panel.slices)
end

local pad_slot

local function SliceLead(panel_index)
	if #shown_sources < 2 then return "" end
	return panel_index == 1 and APHP.L("SHOWN") or APHP.L("COMPARED")
end

local function ShowSliceText(panel_index, slot, anchor)
	local panel = panels[panel_index]
	local slice = panel and panel.slices and panel.slices[slot]
	if not slice then return end
	local lead = SliceLead(panel_index)
	LibAPH.FitLabelText(detail_lbl, lead .. TimelineSliceText(slice, DETAIL_PIECES), { font = Font(12) })
	ShowSlice(panel_index, slot)
	APHP.ShowTip(anchor or panel.plot, TimelineSliceTip(slice, lead ~= "" and lead:gsub("%s+$", "") or nil), win)
end

local function PadShare()
	local span = view_to - view_from
	if not pad_cursor then
		local panel = panels[1]
		local count = panel and panel.slices and #panel.slices or 1
		pad_cursor = view_from + (math.max(1, math.ceil(count / 2)) - 0.5) * span / count
	end
	pad_cursor = zo_clamp(pad_cursor, view_from, view_to)
	return span > 0 and (pad_cursor - view_from) / span or 0.5
end

local function PadSlice(force)
	local panel = panels[1]
	if not panel or not panel.slices or #panel.slices == 0 then
		pad_slot = nil
		return HideSlice()
	end
	local share = PadShare()
	for _, other in ipairs(panels) do
		if other.slices and #other.slices > 0 and not other.plot:IsHidden() then CrosshairAt(other, share * other.plot:GetWidth()) end
	end
	local count = #panel.slices
	local slot = zo_clamp(math.floor(share * count) + 1, 1, count)
	if force or slot ~= pad_slot or not APHP.GetTipText() then
		pad_slot = slot
		ShowSliceText(1, slot, panel.hits and panel.hits[slot])
	end
end

function APHP.MoveTimelineCursor(direction, pixels)
	if not APHP.IsTimelineShown() then return false end
	local panel = panels[1]
	if not panel or not panel.slices or #panel.slices == 0 then return false end
	local span = view_to - view_from
	local start = view_from + PadShare() * span
	local target = zo_clamp(start + direction * (pixels or PAD_TAP_PX) / math.max(panel.plot:GetWidth(), 1) * span, 0, 1)
	if math.abs(target - start) < 1e-12 then return false end
	pad_cursor = target
	if target > view_to then
		local to = math.min(target + span * PAN_EDGE_SHARE, 1)
		APHP.SetTimelineView(to - span, to)
	elseif target < view_from then
		local from = math.max(target - span * PAN_EDGE_SHARE, 0)
		APHP.SetTimelineView(from, from + span)
	else
		PadSlice()
	end
	return true
end

function APHP.GetTimelineCursor()
	return pad_cursor
end

local function OnHover(area)
	local panel = panels[area.aphp_panel]
	if not (panel and panel.slices and panel.slices[area.aphp_slice]) then return end
	Crosshair(panel, area.aphp_slice)
	ShowSliceText(area.aphp_panel, area.aphp_slice, area)
end

local function OnLeave(area)
	local panel = panels[area.aphp_panel]
	if panel then panel.crosshair:SetHidden(true) end
	if detail_lbl.aphp_default then LibAPH.FitLabelText(detail_lbl, detail_lbl.aphp_default, { font = Font(12) }) end
	APHP.HideTip()
	if IsPad() then PadSlice(true) else HideSlice() end
end

local function SliceCenter(area)
	local panel = panels[area.aphp_panel]
	local count = panel and panel.slices and #panel.slices or 1
	return view_from + (view_to - view_from) * (area.aphp_slice - 0.5) / count
end

local function OnWheel(area, delta)
	APHP.ZoomTimeline(delta > 0 and WHEEL_STEP or 1 / WHEEL_STEP, SliceCenter(area))
end

local function StopDrag()
	drag = nil
	if win then win:SetHandler("OnUpdate", nil) end
end

local function OnDragUpdate()
	if not drag then return end
	local x = GetUIMousePosition()
	local shift = -(x - drag.x) / math.max(drag.width, 1) * drag.span
	if math.abs(shift) > 1e-9 then APHP.SetTimelineView(drag.from + shift, drag.from + shift + drag.span) end
end

local function OnPress(area, button)
	if button ~= MOUSE_BUTTON_INDEX_LEFT then return end
	local panel = panels[area.aphp_panel]
	drag = { x = GetUIMousePosition(), from = view_from, span = view_to - view_from, width = panel.plot:GetWidth() }
	win:SetHandler("OnUpdate", OnDragUpdate)
end

local function OnRelease(area, button, upInside)
	StopDrag()
	if upInside and button == MOUSE_BUTTON_INDEX_RIGHT and APHP.OpenTimelineMenu then APHP.OpenTimelineMenu(area) end
end

local function HitArea(panel, index, slot)
	panel.hits = panel.hits or {}
	local area = panel.hits[slot]
	if not area then
		area = WINDOW_MANAGER:CreateControl(string.format("%sHit%d", panel.prefix, slot), panel.plot, CT_CONTROL)
		area:SetMouseEnabled(true)
		area:SetHandler("OnMouseEnter", OnHover)
		area:SetHandler("OnMouseExit", OnLeave)
		area:SetHandler("OnMouseWheel", OnWheel)
		area:SetHandler("OnMouseDown", OnPress)
		area:SetHandler("OnMouseUp", OnRelease)
		panel.hits[slot] = area
	end
	area.aphp_panel, area.aphp_slice = index, slot
	return area
end

local function Panel(index)
	local panel = panels[index]
	if panel then return panel end
	local prefix = WINDOW_NAME .. PANEL_PREFIX[index]
	panel = { prefix = prefix, pool = {}, hits = {}, y_labels = {}, x_labels = {} }
	panel.plot = WINDOW_MANAGER:CreateControl(prefix .. "Graph", win, CT_CONTROL)
	LibAPH.ApplyPanelBackdrop(panel.plot, prefix .. "PlotBG", LibAPH.THEME.INSET)
	panel.title = Label(prefix .. "PanelTitle", win, 13)
	panel.title:SetAnchor(BOTTOMLEFT, panel.plot, TOPLEFT, 0, -3)
	panel.unit = Label(prefix .. "Unit", win, 11, AXIS_TEXT)
	panel.unit:SetAnchor(BOTTOMRIGHT, panel.plot, TOPLEFT, -6, -3)
	panel.crosshair = Rect(prefix .. "Crosshair", panel.plot, { 1, 1, 1, 0.45 })
	panel.crosshair:SetDrawLevel(3)
	panel.crosshair:SetHidden(true)
	panels[index] = panel
	return panel
end

local function AxisLabel(panel, list, key)
	local lbl = panel[list][key]
	if not lbl then
		lbl = Label(string.format("%s%s%d", panel.prefix, list == "y_labels" and "YLabel" or "XLabel", key), win, 11, AXIS_TEXT)
		panel[list][key] = lbl
	end
	return lbl
end

local function HidePanel(panel)
	panel.plot:SetHidden(true)
	panel.title:SetHidden(true)
	panel.unit:SetHidden(true)
	panel.crosshair:SetHidden(true)
	for _, lbl in pairs(panel.y_labels) do lbl:SetHidden(true) end
	for _, lbl in pairs(panel.x_labels) do lbl:SetHidden(true) end
	HidePool(panel)
	for _, area in pairs(panel.hits) do area:SetHidden(true) end
end

local function TextWidthOf(label, text)
	return label:GetStringWidth(LibAPH.StripColors(text or "")) / GetUIGlobalScale()
end

local function LineHeight(panel, set)
	local h = panel.plot:GetHeight()
	if set.stacked then return h end
	return math.max(h - LEADER_H - LEADER_GAP, 1)
end

function APHP.IsTimelineLog()
	return not APHP.saved.timeline_linear
end

function APHP.SetTimelineLog(on)
	APHP.saved.timeline_linear = not on
	APHP.RefreshTimeline()
end

local function ScaleShare(scale, value)
	if not value or value <= 0 then return 0 end
	if not scale.log then return math.min(value / scale.hi, 1) end
	if value <= scale.lo then return 0 end
	return math.min((math.log10(value) - math.log10(scale.lo)) / (math.log10(scale.hi) - math.log10(scale.lo)), 1)
end

local function GridValues(scale)
	local values = {}
	if not scale.log then
		for step = 0, GRID_STEPS do values[#values + 1] = scale.hi * step / GRID_STEPS end
		return values
	end
	values[1] = scale.lo
	local decade = scale.lo * 10
	while decade < scale.hi * 0.999 do
		values[#values + 1] = decade
		decade = decade * 10
	end
	if #values > 1 and scale.hi < values[#values] * LOG_LABEL_ROOM then values[#values] = nil end
	values[#values + 1] = scale.hi
	return values
end

local function DrawGrid(panel, scale, line_h)
	local w = panel.plot:GetWidth()
	local values = GridValues(scale)
	for step, value in ipairs(values) do
		local y = line_h - ScaleShare(scale, value) * line_h
		local line = Pool(panel, "Grid", step - 1)
		line:SetColor(GRID[1], GRID[2], GRID[3], GRID[4])
		line:ClearAnchors()
		line:SetAnchor(TOPLEFT, panel.plot, TOPLEFT, 0, math.min(y, line_h - 1))
		line:SetDimensions(w, 1)
		line:SetHidden(false)
		local lbl = AxisLabel(panel, "y_labels", step - 1)
		lbl:SetText(APHP.Format(value))
		lbl:ClearAnchors()
		lbl:SetAnchor(RIGHT, panel.plot, TOPLEFT, -AXIS_GAP, y)
		lbl:SetHidden(false)
	end
end

local function DrawTicks(panel, set)
	local w, h = panel.plot:GetWidth(), panel.plot:GetHeight()
	local seconds = set.elapsed_ms / 1000
	local from_s, to_s = view_from * seconds, view_to * seconds
	local span = math.max(to_s - from_s, 1e-6)
	local step = APHP.TimeTickStep(span)
	local left_room, right_room = (panel.axis_w or AXIS_W) + PAD, PAD + 8
	local count = 0
	local t = math.ceil(from_s / step - 1e-9) * step
	while t <= to_s + 1e-6 do
		count = count + 1
		local x = (t - from_s) / span * w
		local mark = Pool(panel, "Tick", count)
		mark:SetColor(AXIS_TEXT[1], AXIS_TEXT[2], AXIS_TEXT[3], 0.6)
		mark:ClearAnchors()
		mark:SetAnchor(TOPLEFT, panel.plot, TOPLEFT, math.min(x, w - 1), h)
		mark:SetDimensions(1, TICK_H)
		mark:SetHidden(false)
		local lbl = AxisLabel(panel, "x_labels", count)
		local text = APHP.FormatClock(t)
		lbl:SetText(text)
		local half = TextWidthOf(lbl, text) / 2
		lbl:ClearAnchors()
		lbl:SetAnchor(TOP, panel.plot, TOPLEFT, zo_clamp(x, half - left_room, math.max(w + right_room - half, half - left_room)), h + TICK_H)
		lbl:SetHidden(false)
		t = t + step
	end
	panel.tick_count, panel.tick_step = count, step
end

local function DrawLine(panel, set, key, series_index, color, scale, line_h)
	local w = panel.plot:GetWidth()
	local bar_w = w / #panel.slices
	local prev_y
	for slot, slice in ipairs(panel.slices) do
		local value = SeriesValue(set, key, slice)
		local seg = Pool(panel, "H", series_index .. "_" .. slot)
		local rise = Pool(panel, "V", series_index .. "_" .. slot)
		if value == nil then
			seg:SetHidden(true)
			rise:SetHidden(true)
			prev_y = nil
		else
			local y = line_h - ScaleShare(scale, value) * line_h
			seg:SetColor(color[1], color[2], color[3], 1)
			seg:ClearAnchors()
			seg:SetAnchor(TOPLEFT, panel.plot, TOPLEFT, (slot - 1) * bar_w, zo_clamp(y - LINE_T / 2, math.min(0, line_h - LINE_T), line_h - LINE_T))
			seg:SetDimensions(bar_w, LINE_T)
			seg:SetHidden(false)
			seg.aphp_value = value
			if prev_y and math.abs(prev_y - y) >= 1 then
				rise:SetColor(color[1], color[2], color[3], 1)
				rise:ClearAnchors()
				rise:SetAnchor(TOPLEFT, panel.plot, TOPLEFT, (slot - 1) * bar_w - LINE_T / 2, math.min(prev_y, y))
				rise:SetDimensions(LINE_T, math.abs(prev_y - y))
				rise:SetHidden(false)
			else
				rise:SetHidden(true)
			end
			prev_y = y
		end
	end
end

local function DrawLeaders(panel, set, colors)
	if set.stacked then return end
	local w, h = panel.plot:GetWidth(), panel.plot:GetHeight()
	local bar_w = w / #panel.slices
	for slot, slice in ipairs(panel.slices) do
		local strip = Pool(panel, "Lead", slot)
		if slice.leader then
			local color = colors[slice.leader] or OTHER_COLOR
			strip:SetColor(color[1], color[2], color[3], 0.9)
			strip:ClearAnchors()
			strip:SetAnchor(TOPLEFT, panel.plot, TOPLEFT, (slot - 1) * bar_w, h - LEADER_H)
			strip:SetDimensions(math.max(bar_w - 1, 1), LEADER_H)
			strip:SetHidden(false)
		else
			strip:SetHidden(true)
		end
	end
end

local function SourceTitle(run)
	if run == nil then return APHP.L("LAST_PROFILER_SCAN") end
	return APHP.L("SCAN") .. APHP.DescribeRun(run)
end

local function ZoomNote(set)
	if not APHP.IsTimelineZoomed() then return "" end
	local seconds = set.elapsed_ms / 1000
	return string.format(APHP.L("SHOWING_X"), APHP.FormatClock(view_from * seconds),
		APHP.FormatClock(view_to * seconds), 1 / (view_to - view_from))
end

local function PanelTitleText(set, title)
	local kind = set.stacked and "" or APHP.L("SAVED_SCAN_TOTAL_AND_ITS_TOP")
	return string.format(APHP.L("FRAMES_OVER"), title, set.frames, APHP.FormatClock(set.elapsed_ms / 1000), ZoomNote(set), kind)
end

local function DrawPanel(panel, index, set, scale, colors, legend_order)
	panel.plot:SetHidden(false)
	panel.title:SetHidden(false)
	panel.unit:SetHidden(false)
	panel.unit:SetText(APHP.L("PER_FRAME_2"))

	local line_h = LineHeight(panel, set)
	DrawGrid(panel, scale, line_h)
	DrawTicks(panel, set)
	local hidden = HiddenSeries()
	for series_index, key in ipairs(legend_order) do
		if not hidden[key] then DrawLine(panel, set, key, series_index, colors[key], scale, line_h) end
	end
	DrawLeaders(panel, set, colors)

	local bar_w = panel.plot:GetWidth() / #panel.slices
	for slot = 1, #panel.slices do
		local area = HitArea(panel, index, slot)
		area:ClearAnchors()
		area:SetAnchor(TOPLEFT, panel.plot, TOPLEFT, (slot - 1) * bar_w, 0)
		area:SetDimensions(math.max(bar_w, 1), panel.plot:GetHeight())
		area:SetHidden(false)
	end
end

local function LegendEntry(index)
	local entry = legend[index]
	if entry then return entry end
	local hit = WINDOW_MANAGER:CreateControl(WINDOW_NAME .. "LegendHit" .. index, win, CT_CONTROL)
	hit:SetMouseEnabled(true)
	hit:SetHandler("OnMouseEnter", function(self)
		local text = self.aphp_key and TimelineLegendTip(self.aphp_key)
		if text then APHP.ShowTip(self, text, win) end
	end)
	hit:SetHandler("OnMouseExit", function() APHP.HideTip() end)
	hit:SetHandler("OnMouseUp", function(self, button, upInside)
		if not upInside then return end
		if button == MOUSE_BUTTON_INDEX_LEFT and self.aphp_key then ToggleTimelineSeries(self.aphp_key) end
		if button == MOUSE_BUTTON_INDEX_RIGHT and APHP.OpenTimelineMenu then APHP.OpenTimelineMenu(self) end
	end)
	local sample = Rect(WINDOW_NAME .. "Swatch" .. index, hit, TOTAL_COLOR)
	sample:SetAnchor(LEFT, hit, LEFT, 0, 0)
	sample:SetDimensions(LEGEND_SAMPLE_W, LINE_T)
	local text = Label(WINDOW_NAME .. "Legend" .. index, hit, 12)
	text:SetAnchor(LEFT, sample, RIGHT, 5, 0)
	entry = { hit = hit, sample = sample, text = text }
	legend[index] = entry
	return entry
end

local function LegendRowH()
	return IsPad() and LEGEND_ROW_H_PAD or LEGEND_ROW_H
end

local function LegendColumns(legend_order, inner)
	local measure = LegendEntry(1).text
	measure:SetFont(Font(12))
	local widest = 0
	for _, key in ipairs(legend_order) do widest = math.max(widest, TextWidthOf(measure, SeriesName(key))) end
	local need = LEGEND_SAMPLE_W + 5 + widest + 16
	return zo_clamp(math.floor(inner / math.max(need, 1)), 1, LEGEND_COLUMNS)
end

local function DrawLegend(colors, legend_order, top, columns)
	local width = (win:GetWidth() - PAD * 2) / columns
	local row_h = LegendRowH()
	local hidden = HiddenSeries()
	for index, key in ipairs(legend_order) do
		local entry = LegendEntry(index)
		local color = colors[key]
		local alpha = hidden[key] and 0.3 or 1
		local row = math.floor((index - 1) / columns)
		local col = (index - 1) % columns
		entry.hit.aphp_key = key
		entry.hit:ClearAnchors()
		entry.hit:SetAnchor(TOPLEFT, win, TOPLEFT, PAD + col * width, top + row * row_h)
		entry.hit:SetDimensions(width - 8, row_h)
		entry.sample:SetColor(color[1], color[2], color[3], alpha)
		entry.text:SetColor(0.85, 0.85, 0.85, alpha)
		entry.text:SetDimensions(width - LEGEND_SAMPLE_W - 16, row_h)
		LibAPH.FitLabelText(entry.text, SeriesName(key), { font = Font(12), width = width - LEGEND_SAMPLE_W - 16 })
		entry.hit:SetHidden(false)
	end
	for index = #legend_order + 1, #legend do legend[index].hit:SetHidden(true) end
end

local function TitleLineH()
	return IsPad() and TITLE_LINE_H_PAD or TITLE_LINE_H
end

local function WindowSize(count)
	local w = math.max(APHP.saved.timeline_w or GuiRoot:GetWidth() * WIDTH_SHARE, MIN_WIDTH)
	local h = math.max(APHP.saved.timeline_h or GuiRoot:GetHeight() * (count > 1 and COMPARE_HEIGHT_SHARE or HEIGHT_SHARE), MIN_HEIGHT)
	return w, h
end

local function Layout(count, legend_rows, axis_w, titles)
	local w, h = WindowSize(count)
	win:SetDimensions(w, h)
	local plot_w = math.max(w - PAD * 2 - axis_w - 8, 24)

	local title_h = {}
	for index = 1, #PANEL_PREFIX do
		local panel = Panel(index)
		local text = titles and titles[index]
		if text then
			local wrapped, lines = LibAPH.WrapText(panel.title, text, plot_w)
			panel.title:SetWidth(plot_w)
			panel.title:SetText(wrapped)
			title_h[index] = math.max(lines, 1) * TitleLineH() + 2
		else
			title_h[index] = PANEL_TITLE_H
		end
	end

	local legend_top = PAD + HEADER_H + DETAIL_H
	local top = legend_top + legend_rows * LegendRowH() + 8
	local titles_h = 0
	for index = 1, count do titles_h = titles_h + title_h[index] end
	local plot_h = math.max((h - top - PAD - PANEL_GAP * (count - 1) - titles_h) / count - AXIS_H - TICK_H, 24)
	local y = top
	for index = 1, #PANEL_PREFIX do
		local panel = Panel(index)
		panel.axis_w = axis_w
		y = y + (title_h[index] or PANEL_TITLE_H)
		panel.plot:ClearAnchors()
		panel.plot:SetAnchor(TOPLEFT, win, TOPLEFT, PAD + axis_w, y)
		panel.plot:SetDimensions(plot_w, plot_h)
		y = y + plot_h + AXIS_H + TICK_H + PANEL_GAP
	end
	return legend_top, plot_w
end

local function AxisWidth(scale)
	local measure = AxisLabel(Panel(1), "y_labels", 0)
	local widest = TextWidthOf(Panel(1).unit, APHP.L("PER_FRAME_2"))
	for _, value in ipairs(GridValues(scale)) do widest = math.max(widest, TextWidthOf(measure, APHP.Format(value))) end
	return math.max(math.ceil(widest) + AXIS_GAP + 2, MIN_AXIS_W)
end

local function SlicesFor(sets, plot_w, legend_order)
	local hidden = HiddenSeries()
	local most = math.max(math.floor(plot_w / SLICE_PX), 1)
	local peak, least = 0, nil
	for index, set in ipairs(sets) do
		local panel = Panel(index)
		panel.slices = TimelineSlices(set, view_from, view_to, most)
		for _, slice in ipairs(panel.slices) do
			for _, key in ipairs(legend_order) do
				if not hidden[key] then
					local value = SeriesValue(set, key, slice)
					if value and value > peak then peak = value end
					if value and value > 0 and (not least or value < least) then least = value end
				end
			end
		end
	end
	local hi = APHP.NiceCeiling(peak)
	local scale = { hi = hi, log = APHP.IsTimelineLog() }
	if scale.log then
		local lo = 10 ^ math.floor(math.log10(math.max(least or hi / 10, LOG_FLOOR_MS)) - 1e-9)
		lo = math.max(lo, 10 ^ (math.floor(math.log10(hi)) - LOG_DECADES_MAX))
		if lo >= hi then lo = hi / 10 end
		scale.lo = lo
	end
	return scale
end

local function Draw()
	local top, bottom = APHP.GetCompareSources()
	local shown = APHP.GetRunDetail(top)
	local compared = bottom ~= nil and APHP.GetRunDetail(bottom) or nil
	local sets, titles = {}, {}
	shown_sources = {}

	local shown_set = APHP.TimelineBars(shown)
	if shown_set then
		sets[1], titles[1], shown_sources[1] = shown_set, SourceTitle(top), shown
	end
	local compared_set = shown_set and APHP.TimelineBars(compared) or nil
	if compared_set then
		sets[2], titles[2], shown_sources[2] = compared_set, SourceTitle(bottom), compared
	end

	local shown_key = top or shown
	if view_sources[1] ~= top or view_sources[2] ~= bottom or view_sources.shown ~= shown_key then
		view_sources = { top, bottom, shown = shown_key }
		view_from, view_to = 0, 1
		pad_cursor, pad_slot = nil, nil
	end
	min_span = shown_set and math.max(MIN_SPAN, 2 / shown_set.buckets) or MIN_SPAN
	if view_to - view_from < min_span - 1e-9 then view_from, view_to = 0, 1 end

	for index = 1, #PANEL_PREFIX do HidePanel(Panel(index)) end
	for _, entry in ipairs(legend) do entry.hit:SetHidden(true) end

	LibAPH.FitLabelText(title_lbl, "|c9CD04CAPH-Profiler|r  Timeline" .. (#sets > 1 and APHP.L("TWO_SCANS_SAME_SCALE") or ""), { font = Font(16) })
	empty_lbl:SetHidden(#sets > 0)
	if #sets == 0 then
		shown_sets, shown_titles, shown_legend = {}, {}, {}
		HideSlice()
		Layout(1, 1, AXIS_W)
		empty_lbl:SetText(shown and APHP.L("THIS_SCAN_WAS_SAVED_BEFORE_TIMELINES")
			or APHP.L("NO_SCAN_YET_RUN_ONE_AND"))
		detail_lbl.aphp_default = ""
		detail_lbl:SetText("")
		return
	end

	shown_sets, shown_titles = sets, titles
	local colors, legend_order = TimelineColors(sets)
	shown_legend = legend_order
	local w = WindowSize(#sets)
	local columns = LegendColumns(legend_order, w - PAD * 2)
	local legend_rows = math.max(math.ceil(#legend_order / columns), 1)

	local axis_w = Panel(1).axis_w or AXIS_W
	local _, plot_w = Layout(#sets, legend_rows, axis_w)
	local scale = SlicesFor(sets, plot_w, legend_order)
	local needed = AxisWidth(scale)
	if needed ~= axis_w then
		axis_w = needed
		_, plot_w = Layout(#sets, legend_rows, axis_w)
		scale = SlicesFor(sets, plot_w, legend_order)
	end
	local panel_titles = {}
	for index, set in ipairs(sets) do panel_titles[index] = PanelTitleText(set, titles[index]) end
	local legend_top = Layout(#sets, legend_rows, axis_w, panel_titles)
	APHP.timeline_scale, APHP.timeline_scale_low = scale.hi, scale.lo

	for index, set in ipairs(sets) do DrawPanel(Panel(index), index, set, scale, colors, legend_order) end
	DrawLegend(colors, legend_order, legend_top, columns)

	local default = DefaultDetail(sets)
	if bottom ~= nil and not compared_set then
		default = default .. APHP.L("THE_COMPARED_SCAN_WAS_SAVED_BEFORE")
	end
	detail_lbl.aphp_default = default
	LibAPH.FitLabelText(detail_lbl, default, { font = Font(12) })
	if IsPad() then PadSlice(true) else HideSlice() end
end

local function Build()
	win = WINDOW_MANAGER:CreateTopLevelWindow(WINDOW_NAME)
	win:SetClampedToScreen(true)
	win:SetMouseEnabled(true)
	win:SetMovable(true)
	win:SetDrawTier(DT_HIGH)
	win:SetDrawLayer(DL_OVERLAY)
	win:SetDrawLevel(DRAW_LEVEL)
	win:SetHidden(true)
	local function Resized()
		APHP.saved.timeline_w, APHP.saved.timeline_h = win:GetWidth(), win:GetHeight()
		Draw()
		if APHP.RefreshPadHints then APHP.RefreshPadHints() end
	end
	LibAPH.MakeWindowResizable(win, { handleSize = 8, minWidth = MIN_WIDTH, minHeight = MIN_HEIGHT, onResizing = Resized, onResizeStop = Resized })
	win:SetHandler("OnMoveStop", function()
		APHP.saved.timeline_x, APHP.saved.timeline_y = win:GetLeft(), win:GetTop()
	end)
	win:SetHandler("OnMouseUp", function(control, button, upInside)
		if upInside and button == MOUSE_BUTTON_INDEX_RIGHT and APHP.OpenTimelineMenu then APHP.OpenTimelineMenu(control) end
	end)

	LibAPH.ApplyPanelBackdrop(win, WINDOW_NAME .. "BG", LibAPH.THEME.BG)
	LibAPH.CreateHeaderStrip(win, WINDOW_NAME .. "Header", HEADER_H + PAD / 2)

	title_lbl = Label(WINDOW_NAME .. "Title", win, 16)
	title_lbl:SetAnchor(TOPLEFT, win, TOPLEFT, PAD, PAD - 2)
	title_lbl:SetAnchor(TOPRIGHT, win, TOPRIGHT, -PAD - CLOSE_BTN_SIZE - 10 - (ZOOM_BTN_W + 6) * 3, PAD - 2)

	detail_lbl = Label(WINDOW_NAME .. "Detail", win, 12, AXIS_TEXT)
	detail_lbl:SetMaxLineCount(1)
	detail_lbl:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
	detail_lbl:SetAnchor(TOPLEFT, win, TOPLEFT, PAD, PAD + HEADER_H)
	detail_lbl:SetAnchor(TOPRIGHT, win, TOPRIGHT, -PAD, PAD + HEADER_H)

	local close = LibAPH.CreateThemedCloseButton(win, WINDOW_NAME .. "Close", function() APHP.HideTimeline() end, PAD, PAD)

	local function HeaderButton(suffix, text, right_of, onClick)
		local btn = WINDOW_MANAGER:CreateControlFromVirtual(WINDOW_NAME .. suffix, win, "ZO_DefaultButton")
		btn:SetDimensions(ZOOM_BTN_W, 24)
		btn:SetFont(IsPad() and "ZoFontGamepad18" or "ZoFontGameSmall")
		btn:SetText(text)
		btn:SetAnchor(RIGHT, right_of, LEFT, right_of == close and -10 or -6, 0)
		btn:SetHandler("OnClicked", onClick)
		return btn
	end
	local full = HeaderButton("ZoomFull", "Full", close, function() APHP.ResetTimelineZoom() end)
	local zoom_out = HeaderButton("ZoomOut", APHP.L("ZOOM_OUT"), full, function() APHP.ZoomTimeline(1 / ZOOM_STEP) end)
	local zoom_in = HeaderButton("ZoomIn", APHP.L("ZOOM_IN"), zoom_out, function() APHP.ZoomTimeline(ZOOM_STEP) end)
	LibAPH.FitButtonRow(win, { zoom_in, zoom_out, full }, {
		gap = 6,
		font = IsPad() and "ZoFontGamepad18" or "ZoFontGameSmall",
		room = function() return win:GetWidth() - 2 * PAD - close:GetWidth() - 10 end,
	})

	for index = 1, #PANEL_PREFIX do Panel(index) end

	empty_lbl = Label(WINDOW_NAME .. "Empty", win, 14)
	empty_lbl:SetAnchor(CENTER, win, CENTER, 0, 0)

	win:ClearAnchors()
	if APHP.saved.timeline_x and APHP.saved.timeline_y then
		win:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, APHP.saved.timeline_x, APHP.saved.timeline_y)
	else
		win:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
	end

	APHP.timeline_mover = LibAPH.CreateGamepadMover(win)
	APHP.timeline_mover:RegisterCallback(APHP.name .. "_Timeline", 2, function(pos)
		if type(pos.left) == "number" then APHP.saved.timeline_x = pos.left end
		if type(pos.top) == "number" then APHP.saved.timeline_y = pos.top end
		if APHP.OnPadStickStopped then APHP.OnPadStickStopped() end
	end)
	APHP.timeline_resizer = LibAPH.CreateGamepadResizer(win, {
		minWidth = MIN_WIDTH,
		minHeight = MIN_HEIGHT,
		onResizing = function()
			APHP.saved.timeline_w, APHP.saved.timeline_h = win:GetWidth(), win:GetHeight()
			Draw()
			if APHP.RefreshPadHints then APHP.RefreshPadHints() end
		end,
		onResizeStop = function()
			if APHP.OnPadStickStopped then APHP.OnPadStickStopped() end
		end,
	})

	APHP.timeline_sticky = LibAPH.CreateStickyFragment(win, { "hud", "hudui" })
	APHP.timeline_fragment = APHP.timeline_sticky.fragment
end

function TimelineLegendTip(key)
	for _, source in ipairs(shown_sources) do
		if key == TOTAL then
			return string.format(APHP.L("TOTAL_ADD_ON_LUA_N_NEVERY"),
				APHP.Format(source.measured_ms or 0), source.frames or 0)
		end
		for _, row in ipairs(source.rows or {}) do
			if row.owner == key then return APHP.OwnerTooltipText(row, source) end
		end
	end
	return nil
end

function APHP.GetTimelineWindow() return win end

function APHP.IsTimelineShown()
	return win ~= nil and not win:IsHidden()
end

function APHP.ShowTimeline()
	if not win then Build() end
	if APHP.HideLoadTimes then APHP.HideLoadTimes() end
	Draw()
	APHP.timeline_sticky:Open()
	if APHP.RefreshPadHints then APHP.RefreshPadHints() end
	return true
end

function APHP.HideTimeline()
	if not win then return false end
	StopDrag()
	APHP.HideTip()
	if APHP.StopPadHold then APHP.StopPadHold() end
	APHP.timeline_mover:ToggleGamepadMove(false)
	APHP.timeline_resizer:ToggleGamepadResize(false)
	APHP.timeline_sticky:Close()
	if APHP.RefreshPadHints then APHP.RefreshPadHints() end
	return true
end

function APHP.ToggleTimeline()
	if APHP.IsTimelineShown() then return APHP.HideTimeline() end
	return APHP.ShowTimeline()
end

function APHP.RefreshTimeline()
	if not APHP.IsTimelineShown() then return false end
	Draw()
	return true
end
