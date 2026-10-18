--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

local APHP = APHProfilerCore
local BuildHudLines, BuildSummaryLines, SaveHudPosition

local HUD_NAME = "APHProfilerHUD"
local PAD_X = 5
local PAD_Y = 5
local EXTRA_W = 20
local EXTRA_H = 15
local MIN_HEIGHT = 60
local MIN_WIDTH_PC = 280
local MIN_WIDTH_CONSOLE = 380
local RESIZE_HANDLE = 8
local BUTTON_GAP = 10
local BASE_FONT_SIZE = 14
local MIN_FONT_SIZE = 10
local MAX_FONT_SIZE = 30
local MEASURE_W = 6000
local MEASURE_H = 400
local MAX_FIT_HEIGHT_SHARE = 0.6
local SCROLLBAR_W = 6
local SCROLLBAR_GAP = 4
local WHEEL_LINES = 3
local MIN_THUMB_H = 16
local HEADER_H = 30
local HEADER_BTN_GAP = 6
local STATUS_RESERVE = 150
local TITLE_TEXT = "|c9CD04CAPH-Profiler|r"
local TIMER_NAMESPACE = "APHProfiler_RecordingTimer"
local TIMER_MS = 1000
local SCAN_LINE_NAME = "APHProfilerScanStatus"
local SCAN_LINE_ORDER = 2
local SCAN_LINE_TITLE = "|c9CD04CAPH-Profiler|r  "
local FOCUS_LAYER = "APHProfiler_HudFocus"
local CLOSE_BTN_SIZE = LibAPH.THEME.CLOSE_SIZE
local PAD_TIMELINE_ZOOM = 0.5
local PAD_HOLD = { delay = 250, slow = 120, fast = 600, ramp = 1500 }
local PAD_HOLD_JOB = "APHProfiler_PadHold"
local PAD_CONTROL_JOB = "APHProfiler_PadControl"

local hud
local status_lbl
local measure_lbl
local scan_btn
local timeline_btn
local summary_btn
local view = "results"
local HUD_BUTTONS = 3
local SUMMARY_FUNCS = 3
local row_labels = {}
local row_bgs = {}
local title_lbl
local export_box
local expanded = {}
local compare_a
local compare_b
local compare_b_set
local hud_lines = {}
local focus_index = 0
local focus_mode = false
local move_mode = false
local scroll_offset = 0
local max_scroll = 0
local scroll_track
local scroll_thumb
local scroll_grab
local GRAB_W = 16
local pad_hints
local hud_resizer

local function IsPad() return IsConsoleUI() or IsInGamepadPreferredMode() end

local function FontSize()
	local size = APHP.saved.hud_font_size
	if type(size) ~= "number" then return BASE_FONT_SIZE end
	if size < MIN_FONT_SIZE then return MIN_FONT_SIZE end
	if size > MAX_FONT_SIZE then return MAX_FONT_SIZE end
	return size
end

local PAD_FONT_SIZES = { 18, 20, 22, 25, 27, 34, 36 }
local PAD_BASE_FONT = 18

local function FontForSize(size)
	if IsPad() then
		local wanted = size * PAD_BASE_FONT / BASE_FONT_SIZE
		local pick = PAD_FONT_SIZES[1]
		for _, real in ipairs(PAD_FONT_SIZES) do
			if real <= wanted + 0.5 then pick = real end
		end
		return "ZoFontGamepad" .. pick
	end
	return "$(CHAT_FONT)|" .. size .. "|soft-shadow-thin"
end

local function RowFont() return FontForSize(FontSize()) end
local function Cyan(text) return "|c00FFFF" .. text .. "|r" end

local function OwnerLine(index, name, ms, per_frame, delta, before, is_new)
	return string.format("  %d. %s |c%s[%s]|r%s%s%s",
		index, APHP.Format(ms), APHP.SeverityColor(ms), name,
		per_frame and ("  " .. APHP.Format(per_frame) .. "/frame") or "",
		APHP.FormatDelta(delta, before),
		is_new and APHP.L("NOT_IN_THE_COMPARED_SCAN") or "")
end

local function SourceRows(run)
	if run == nil then
		local report = APHP.GetLastReport()
		if not report then return nil end
		local rows = {}
		for index, row in ipairs(report.rows) do
			rows[index] = { o = row.owner, m = row.own, pf = row.per_frame or 0 }
		end
		local title = APHP.L("LAST_PROFILER_SCAN")
		return rows, title, report.frames, report.elapsed_ms, report.measured_ms
	end

	local rows = APHP.GetRunRows(run)
	local total = 0
	for _, row in ipairs(rows) do
		row.pf = (run.frames or 0) > 0 and row.m / run.frames or 0
		total = total + row.m
	end
	return rows, APHP.L("SCAN") .. APHP.DescribeRun(run), run.frames, run.elapsed_ms, total
end

local function SourceLabel(run)
	if run == nil then return APHP.GetLastReport() and APHP.L("THIS_RUN") or APHP.L("THIS_RUN_NONE_YET") end
	return APHP.DescribeRun(run)
end

function APHP.GetCompareSources()
	local bottom = compare_b
	if not compare_b_set and APHP.saved.show_previous_scan then
		local previous = APHP.GetPreviousRun()
		local top_report = APHP.GetLastReport()
		if previous and (compare_a ~= nil or not top_report or previous.at ~= top_report.at) then
			bottom = previous
		end
	end
	if bottom ~= nil and bottom == compare_a then bottom = nil end
	return compare_a, bottom
end

local function SectionLines(lines, rows, title, frames, elapsed_ms, measured_ms, against, interactive)
	lines[#lines + 1] = { text = string.format(APHP.L("FRAMES_OVER_S_ADD_ON_LUA"),
		Cyan("[" .. title .. "]"), frames or 0, (elapsed_ms or 0) / 1000, APHP.Format(measured_ms or 0)), section = true }

	local limit = math.min(APHP.GetListLimit(), #rows)

	local report = interactive and APHP.GetLastReport() or nil
	local detail, report_rows = {}, {}
	if report then
		for _, row in ipairs(report.rows) do
			detail[row.owner] = row.funcs
			report_rows[row.owner] = row
		end
	end
	local section_detail = report or { frames = frames, measured_ms = measured_ms }

	for index = 1, limit do
		local row = rows[index]
		local delta, before
		if against and against[row.o] then
			before = against[row.o]
			delta = row.pf - before
		end
		local is_new = against ~= nil and against[row.o] == nil

		local funcs = detail[row.o]
		local open = expanded[row.o] == true
		local has_detail = funcs and #funcs > 0
		lines[#lines + 1] = {
			text = OwnerLine(index, row.o, row.m, row.pf, delta, before, is_new)
				.. (has_detail and (open and "  |c888888-|r" or "  |c888888+|r") or ""),
			owner = has_detail and row.o or nil,
			tip = function()
				return APHP.OwnerTooltipText(report_rows[row.o] or { owner = row.o, own = row.m }, section_detail)
			end,
		}
		if has_detail and open then
			for _, entry in ipairs(funcs) do
				lines[#lines + 1] = {
					text = string.format(APHP.L("CALLS_2"),
						APHP.Format(entry.own), entry.label, entry.calls, APHP.FunctionStats(entry)),
					detail = true,
					tip = function() return APHP.FunctionTooltipText(entry, row.o, frames) end,
				}
			end
		end
	end

	if limit < #rows then
		lines[#lines + 1] = { text = string.format(APHP.L("MORE_BELOW_THAT_ALL_SMALLER"), #rows - limit) }
	end
end

local NAMES_LISTED = 8
local SAME_PERCENT = 2
local SAME_PER_FRAME_MS = 0.0005

local function PerFrame(total, frames)
	if not frames or frames <= 0 then return 0 end
	return (total or 0) / frames
end

local function GroupLine(lines, color, title, items, describe)
	if #items == 0 then return end
	local shown = {}
	for index = 1, math.min(#items, NAMES_LISTED) do shown[index] = describe(items[index]) end
	local text = table.concat(shown, ", ")
	if #items > NAMES_LISTED then text = text .. string.format(APHP.L("AND_MORE"), #items - NAMES_LISTED) end
	lines[#lines + 1] = { text = string.format("  |c%s%s (%d):|r %s", color, title, #items, text) }
end

local function Change(item)
	return string.format("%s |c%s%s%s%s|r", item.o, item.delta > 0 and "FF6666" or "66FF66",
		item.delta > 0 and "+" or "-", APHP.Format(math.abs(item.delta)), APHP.FormatPercent(item.delta, item.was))
end

local function JustName(item) return item.o end

function APHP.IsSameCost(now, was)
	local delta = math.abs(now - was)
	if delta < SAME_PER_FRAME_MS then return true end
	return was > 0 and delta / was * 100 < SAME_PERCENT
end

function APHP.ComparisonLines(lines, top, bottom)
	local now = PerFrame(top.total, top.frames)
	local was = PerFrame(bottom.total, bottom.frames)
	local change = now - was
	local color = change > 0 and "FF6666" or "66FF66"

	lines[#lines + 1] = { text = APHP.L("COMPARED_WITH") .. bottom.title .. "]|r", section = true }
	lines[#lines + 1] = { text = string.format(APHP.L("ADD_ON_LUA_PER_FRAME_SHOWN"),
		APHP.Format(now), APHP.Format(was), color, change >= 0 and "+" or "-",
		APHP.Format(math.abs(change)), APHP.FormatPercent(change, was)) }
	lines[#lines + 1] = { text = string.format(APHP.L("LENGTH_FRAMES_OVER_S_SHOWN_FRAMES"),
		top.frames or 0, (top.elapsed or 0) / 1000, bottom.frames or 0, (bottom.elapsed or 0) / 1000) }

	local before, seen = {}, {}
	for _, row in ipairs(bottom.rows) do before[row.o] = row.pf end
	local slower, faster, same, added, missing = {}, {}, {}, {}, {}
	for _, row in ipairs(top.rows) do
		seen[row.o] = true
		local was_pf = before[row.o]
		if was_pf == nil then
			added[#added + 1] = { o = row.o }
		else
			local item = { o = row.o, delta = row.pf - was_pf, was = was_pf }
			if APHP.IsSameCost(row.pf, was_pf) then
				same[#same + 1] = item
			elseif item.delta > 0 then
				slower[#slower + 1] = item
			else
				faster[#faster + 1] = item
			end
		end
	end
	for _, row in ipairs(bottom.rows) do
		if not seen[row.o] then missing[#missing + 1] = { o = row.o } end
	end
	table.sort(slower, function(x, y) return x.delta > y.delta end)
	table.sort(faster, function(x, y) return x.delta < y.delta end)

	GroupLine(lines, "FF6666", "Slower", slower, Change)
	GroupLine(lines, "66FF66", "Faster", faster, Change)
	GroupLine(lines, "CCCCCC", string.format(APHP.L("ABOUT_THE_SAME_WITHIN"), SAME_PERCENT), same, JustName)
	GroupLine(lines, "66CCFF", APHP.L("ONLY_IN_THE_SHOWN_SCAN"), added, JustName)
	GroupLine(lines, "888888", APHP.L("ONLY_IN_THE_COMPARED_SCAN"), missing, JustName)
end

local function SecondsAt(frame, frames, elapsed_ms)
	if not frames or frames <= 0 then return 0 end
	return (frame / frames) * (elapsed_ms or 0) / 1000
end

local function SummaryLeftOut()
	local mask = 0
	if APHP.saved.summary_hide_game_ui == true then mask = mask + 1 end
	if APHP.saved.summary_hide_gc == true then mask = mask + 2 end
	return mask
end

local function WorstFrames(detail)
	local source = detail.timeline or detail.compact
	if not source then return {}, false end
	local mask = SummaryLeftOut()
	if mask == 0 then return source.worst or {}, false end
	local without = type(source.worst_without) == "table" and source.worst_without[mask]
	if without then return without, false end
	return source.worst or {}, true
end

local function LeftOutNames()
	local names = {}
	if APHP.saved.summary_hide_game_ui == true then names[#names + 1] = LibAPH.StripColors(APHP.L("GAME_UI")) end
	if APHP.saved.summary_hide_gc == true then names[#names + 1] = LibAPH.StripColors(APHP.L("LUA_GARBAGE_COLLECTOR")) end
	return table.concat(names, APHP.L("AND_JOIN"))
end

local function WasText(now, was)
	if not was then return "" end
	local delta = now - was
	if APHP.IsSameCost(now, was) then return string.format(APHP.L("WAS_ABOUT_THE_SAME"), APHP.Format(was)) end
	return string.format(APHP.L("CWAS"), delta > 0 and "FF6666" or "66FF66", APHP.Format(was),
		delta > 0 and "+" or "-", APHP.Format(math.abs(delta)), APHP.FormatPercent(delta, was))
end

local function FrameLines(lines, detail, title)
	local frames, elapsed = detail.frames or 0, detail.elapsed_ms or 0
	lines[#lines + 1] = { text = string.format(APHP.L("FRAMES_OVER_S"), title, frames, elapsed / 1000), section = true }
	if frames > 0 and elapsed > 0 then
		local frame_ms = elapsed / frames
		lines[#lines + 1] = { text = string.format(APHP.L("AVERAGE_FRAME_FPS_ADD_ON_LUA"),
			APHP.Format(frame_ms), 1000 / frame_ms, APHP.Format((detail.measured_ms or 0) / frames),
			(detail.measured_ms or 0) / elapsed * 100) }
	end
end

local function SpikeLines(lines, detail, heading)
	local worst, older = WorstFrames(detail)
	if #worst == 0 then return end
	if SummaryLeftOut() > 0 and not older then heading = heading:gsub(":$", "") .. string.format(APHP.L("HEAVIEST_LEAVING_OUT"), LeftOutNames()) end
	lines[#lines + 1] = { text = "  |cFFD700" .. heading .. "|r" }
	if older then lines[#lines + 1] = { text = "  |c888888" .. string.format(APHP.L("HEAVIEST_OLDER_SCAN"), LeftOutNames()) .. "|r" } end
	for _, spike in ipairs(worst) do
		lines[#lines + 1] = { text = string.format(APHP.L("OF_ADD_ON_LUA_AROUND_S"),
			APHP.Format(spike.ms), SecondsAt(spike.frame, detail.frames, detail.elapsed_ms), spike.owner or "?",
			APHP.Format(spike.owner_ms or 0)) }
	end
end

local function PerFrameOf(ms, frames)
	if not frames or frames <= 0 then return 0 end
	return (ms or 0) / frames
end

function BuildSummaryLines()
	local lines = {}
	local top, bottom = APHP.GetCompareSources()
	local shown = APHP.GetRunDetail(top)
	if not shown or #(shown.rows or {}) == 0 then
		lines[#lines + 1] = { text = Cyan(APHP.L("SUMMARY")), section = true }
		lines[#lines + 1] = { text = APHP.L("NOTHING_TO_SUMMARISE_YET_SO_RUN") }
		return lines
	end
	local compared = bottom ~= nil and APHP.GetRunDetail(bottom) or nil
	local top_title = top == nil and APHP.L("LAST_PROFILER_SCAN") or (APHP.L("SCAN") .. APHP.DescribeRun(top))

	FrameLines(lines, shown, Cyan(APHP.L("SUMMARY_2") .. top_title .. "]"))
	if compared then
		FrameLines(lines, compared, APHP.L("COMPARED_WITH_SCAN") .. APHP.DescribeRun(bottom) .. "]|r")
	end
	SpikeLines(lines, shown, compared and APHP.L("HEAVIEST_FRAMES_SHOWN") or APHP.L("HEAVIEST_FRAMES"))
	if compared then SpikeLines(lines, compared, APHP.L("HEAVIEST_FRAMES_COMPARED")) end

	local before = {}
	if compared then
		for _, row in ipairs(compared.rows) do before[row.owner] = row end
	end

	lines[#lines + 1] = { text = APHP.L("COSTING_THE_MOST") }
	local listed = math.min(#shown.rows, APHP.GetListLimit())
	for index = 1, listed do
		local row = shown.rows[index]
		local share = (shown.measured_ms or 0) > 0 and row.own / shown.measured_ms * 100 or 0
		local per_frame = PerFrameOf(row.own, shown.frames)
		local tail = ""
		if compared then
			local old = before[row.owner]
			tail = old and WasText(per_frame, PerFrameOf(old.own, compared.frames)) or APHP.L("NOT_IN_THE_COMPARED_SCAN")
		end
		lines[#lines + 1] = { text = string.format(APHP.L("C_OF_ADD_ON_LUA_PER"),
			index, APHP.SeverityColor(row.own), row.owner, APHP.Format(row.own), share, APHP.Format(per_frame),
			row.peak and (APHP.L("WORST_CALL") .. APHP.Format(row.peak)) or "", tail),
			tip = function() return APHP.OwnerTooltipText(row, shown) end }

		local old_funcs = {}
		for _, entry in ipairs((before[row.owner] or {}).funcs or {}) do old_funcs[entry.label] = entry end
		for f = 1, math.min(#(row.funcs or {}), SUMMARY_FUNCS) do
			local entry = row.funcs[f]
			local func_tail = ""
			if compared then
				local old = old_funcs[entry.label]
				func_tail = old and WasText(PerFrameOf(entry.own, shown.frames), PerFrameOf(old.own, compared.frames)) or ""
			end
			lines[#lines + 1] = { text = string.format(APHP.L("FRAME_CALLS"),
				APHP.Format(entry.own), APHP.Format(PerFrameOf(entry.own, shown.frames)), entry.label, entry.calls,
				APHP.FunctionStats(entry), func_tail),
				detail = true,
				tip = function() return APHP.FunctionTooltipText(entry, row.owner, shown.frames) end }
		end
	end
	if #shown.rows > listed then
		lines[#lines + 1] = { text = string.format(APHP.L("MORE_BELOW_THAT_ALL_SMALLER"), #shown.rows - listed) }
	end
	if shown.rows[1] and shown.rows[1].owner == APHP.ESOUI_OWNER then
		lines[#lines + 1] = { text = APHP.L("GAME_UI_IS_ZOS_S_OWN") }
	end
	if compared and not compared.session then
		lines[#lines + 1] = { text = APHP.L("THE_COMPARED_SCAN_WAS_SAVED_IT") }
	end
	return lines
end

function APHP.GetHudView() return view end

function APHP.ToggleSummaryView()
	view = view == "summary" and "results" or "summary"
	scroll_offset = 0
	focus_index = 0
	APHP.RefreshHud()
	return view
end

function BuildHudLines()
	if view == "summary" then return BuildSummaryLines() end
	local lines = {}
	local top, bottom = APHP.GetCompareSources()

	local top_rows, top_title, top_frames, top_elapsed, top_total = SourceRows(top)
	if not top_rows then
		lines[#lines + 1] = { text = APHP.L("NO_SCAN_YET_PRESS_SCAN_REPRODUCE") }
		local runs = APHP.GetRuns()
		if #runs > 0 then
			lines[#lines + 1] = { text = string.format(APHP.L("SAVED_SCAN_RIGHT_CLICK_TO_READ"),
				#runs, #runs == 1 and "" or "s") }
		end
		return lines
	end

	local against
	local bottom_rows, bottom_title, bottom_frames, bottom_elapsed, bottom_total
	if bottom ~= nil then
		bottom_rows, bottom_title, bottom_frames, bottom_elapsed, bottom_total = SourceRows(bottom)
	end
	if bottom_rows then
		against = {}
		for _, row in ipairs(bottom_rows) do against[row.o] = row.pf end
	end

	if bottom_rows then
		APHP.ComparisonLines(lines,
			{ rows = top_rows, frames = top_frames, elapsed = top_elapsed, total = top_total },
			{ rows = bottom_rows, frames = bottom_frames, elapsed = bottom_elapsed, total = bottom_total,
				title = bottom_title })
	end
	SectionLines(lines, top_rows, top_title, top_frames, top_elapsed, top_total, against, top == nil)
	if bottom_rows then
		SectionLines(lines, bottom_rows, bottom_title, bottom_frames, bottom_elapsed, bottom_total, nil, false)
	end
	return lines
end

function APHP.GetHudLines() return hud_lines end
function APHP.IsHudFocused() return focus_mode end
function APHP.IsHudMoveMode() return move_mode end
function APHP.GetHudFocusIndex() return focus_index end

local function PickableLines()
	local picks = {}
	for index, line in ipairs(hud_lines) do
		if line.owner then picks[#picks + 1] = index end
	end
	return picks
end

local function LoadTimesFront()
	return APHP.IsLoadTimesShown ~= nil and APHP.IsLoadTimesShown()
end

local function HudInFront()
	return not LoadTimesFront() and not (APHP.IsTimelineShown and APHP.IsTimelineShown())
end

function APHP.MoveHudFocus(direction)
	if not focus_mode then return false end
	if LibAPH.GetContextMenuDepth() > 0 then return LibAPH.MoveContextMenuFocus(direction) end
	if IsPad() and LoadTimesFront() then return APHP.ScrollLoadTimes(direction) end
	if IsPad() and APHP.IsTimelineShown() then return true end

	local picks = PickableLines()
	if #picks == 0 then return false end

	local current = 0
	for slot, line_index in ipairs(picks) do
		if line_index == focus_index then current = slot break end
	end
	current = current + direction
	if current < 1 then current = #picks elseif current > #picks then current = 1 end
	focus_index = picks[current]
	APHP.RefreshHud()
	return true
end

local function PadKey(action)
	return LibAPH.GetKeybindMarkup(action)
end

local function StickTools()
	if LoadTimesFront() then return APHP.load_mover, APHP.load_resizer end
	if APHP.IsTimelineShown() then return APHP.timeline_mover, APHP.timeline_resizer end
	return APHP.hud_mover, hud_resizer
end

local function PadHintParts()
	local parts = {}
	local function Add(text, ...)
		local keys = {}
		for _, action in ipairs({ ... }) do keys[#keys + 1] = PadKey(action) end
		parts[#parts + 1] = table.concat(keys, "") .. " " .. text
	end
	if LibAPH.GetContextMenuDepth() > 0 then
		Add("Choose", "UI_SHORTCUT_PRIMARY")
		Add("Back", "UI_SHORTCUT_NEGATIVE")
		return parts
	end

	local mover, resizer = StickTools()
	if LoadTimesFront() then
		Add("Scroll", "UI_SHORTCUT_INPUT_UP", "UI_SHORTCUT_INPUT_DOWN")
		Add("Page", "UI_SHORTCUT_LEFT_TRIGGER", "UI_SHORTCUT_RIGHT_TRIGGER")
		Add("Menu", "UI_SHORTCUT_TERTIARY")
		Add(mover and mover:IsMoving() and "Moving" or "Move", "UI_SHORTCUT_RIGHT_STICK")
		Add(resizer and resizer:IsResizing() and "Resizing" or "Resize", "UI_SHORTCUT_LEFT_STICK")
		Add(APHP.L("CLOSE_LOAD_TIMES"), "UI_SHORTCUT_NEGATIVE")
		return parts
	end
	if APHP.IsTimelineShown() then
		Add("Zoom", "UI_SHORTCUT_LEFT_TRIGGER", "UI_SHORTCUT_RIGHT_TRIGGER")
		Add("Move", "UI_SHORTCUT_INPUT_LEFT", "UI_SHORTCUT_INPUT_RIGHT")
		Add(APHP.IsRunning() and "Stop" or "Scan", "UI_SHORTCUT_SECONDARY")
		Add("Menu", "UI_SHORTCUT_TERTIARY")
		Add(APHP.L("HIDE_TIMELINE"), "UI_SHORTCUT_RIGHT_SHOULDER")
		Add(mover and mover:IsMoving() and "Moving" or "Move", "UI_SHORTCUT_RIGHT_STICK")
		Add(resizer and resizer:IsResizing() and "Resizing" or "Resize", "UI_SHORTCUT_LEFT_STICK")
		Add(APHP.L("CLOSE_TIMELINE"), "UI_SHORTCUT_NEGATIVE")
		return parts
	end

	Add(APHP.L("OPEN_ROW"), "UI_SHORTCUT_PRIMARY")
	Add(APHP.IsRunning() and "Stop" or "Scan", "UI_SHORTCUT_SECONDARY")
	Add("Menu", "UI_SHORTCUT_TERTIARY")
	Add(view == "summary" and "Results" or "Summary", "UI_SHORTCUT_LEFT_SHOULDER")
	Add("Timeline", "UI_SHORTCUT_RIGHT_SHOULDER")
	Add("Page", "UI_SHORTCUT_LEFT_TRIGGER", "UI_SHORTCUT_RIGHT_TRIGGER")
	Add(move_mode and "Moving" or "Move", "UI_SHORTCUT_RIGHT_STICK")
	Add(resizer and resizer:IsResizing() and "Resizing" or "Resize", "UI_SHORTCUT_LEFT_STICK")
	Add("Close", "UI_SHORTCUT_NEGATIVE")
	return parts
end

local function RefreshPadHints()
	if not pad_hints then return end
	if not (focus_mode and IsPad() and hud ~= nil and not hud:IsHidden() and APHP.saved.pad_hints ~= false) then
		APHP.hint_below, APHP.hint_above = pad_hints:Hide()
		APHP.pad_hint_owner = nil
		return
	end
	local owner = (LoadTimesFront() and APHP.GetLoadTimesWindow()) or (APHP.IsTimelineShown() and (APHP.GetTimelineDock() or APHP.GetTimelineWindow())) or hud
	APHP.hint_below, APHP.hint_above = pad_hints:Show(owner, PadHintParts())
	APHP.pad_hint_owner = owner
end
APHP.RefreshPadHints = RefreshPadHints

function APHP.GetHudControl() return hud end

function APHP.OnPadStickStopped()
	RefreshPadHints()
end

function APHP.GetPadHintText()
	return pad_hints and pad_hints:GetText() or nil
end

function APHP.ActivateHudFocus()
	if not focus_mode then return false end
	if LibAPH.GetContextMenuDepth() > 0 then
		local done = LibAPH.ActivateContextMenuFocus()
		RefreshPadHints()
		return done
	end
	if IsPad() and (LoadTimesFront() or APHP.IsTimelineShown()) then return true end

	local line = hud_lines[focus_index]
	if not line or not line.owner then return false end
	return APHP.ToggleOwnerExpanded(line.owner)
end

function APHP.OpenHudMenu()
	if not hud or hud:IsHidden() then return false end
	if LibAPH.GetContextMenuDepth() > 0 then
		LibAPH.CloseContextMenu()
		return true
	end
	APHP.ShowMenu(hud, APHP.BuildResultsMenuEntries, hud)
	if focus_mode then LibAPH.MoveContextMenuFocus(1) end
	RefreshPadHints()
	return true
end

local function SetFocusLayer(active)
	local on = IsActionLayerActiveByName(FOCUS_LAYER)
	if active and not on then
		PushActionLayerByName(FOCUS_LAYER)
	elseif not active and on then
		RemoveActionLayerByName(FOCUS_LAYER)
	end
end

function APHP.ToggleHudFocus()
	if not hud or hud:IsHidden() then return false end
	if focus_mode and LibAPH.GetContextMenuDepth() > 0 then
		LibAPH.CloseContextMenu()
		APHP.RefreshHud()
		return true
	end

	focus_mode = not focus_mode
	SetFocusLayer(focus_mode)
	if focus_mode then
		local picks = PickableLines()
		focus_index = picks[1] or 0
	else
		focus_index = 0
		LibAPH.CloseContextMenu()
		APHP.HideTip()
		if move_mode then APHP.ToggleHudMoveMode() end
		if hud_resizer then hud_resizer:ToggleGamepadResize(false) end
	end
	APHP.RefreshHud()
	return true
end

function APHP.ToggleHudMoveMode()
	if not hud or hud:IsHidden() then return false end
	if not APHP.hud_mover then return false end
	if APHP.saved.hud_locked then
		APHP.Print(APHP.L("THE_HUD_IS_LOCKED_UNLOCK_IT"), true)
		return false
	end
	move_mode = not move_mode
	if move_mode and hud_resizer then hud_resizer:ToggleGamepadResize(false) end
	APHP.hud_mover:ToggleGamepadMove(move_mode)
	if move_mode then APHP.SetHudStatus(APHP.L("RIGHT_STICK_MOVES_THE_HUD")) else APHP.RestoreHudStatus() end
	RefreshPadHints()
	return true
end

function APHP.ToggleHudResizeMode()
	if not hud or hud:IsHidden() or not hud_resizer then return false end
	if APHP.saved.hud_locked then
		APHP.Print(APHP.L("THE_HUD_IS_LOCKED_UNLOCK_IT"), true)
		return false
	end
	local resizing = not hud_resizer:IsResizing()
	if resizing and move_mode then APHP.ToggleHudMoveMode() end
	hud_resizer:ToggleGamepadResize(resizing)
	if resizing then APHP.SetHudStatus(APHP.L("LEFT_STICK_RESIZES_THE_HUD")) else APHP.RestoreHudStatus() end
	RefreshPadHints()
	return true
end

local function PadScroll(direction)
	if LoadTimesFront() then return APHP.ScrollLoadTimes(direction * APHP.LoadTimesPage()) end
	if APHP.IsTimelineShown() then
		APHP.ZoomTimeline(direction < 0 and 1 / PAD_TIMELINE_ZOOM or PAD_TIMELINE_ZOOM, APHP.GetTimelineCursor())
		return true
	end
	local lines = math.max((APHP.hud_visible_rows or 1) - 1, 1)
	local picks = PickableLines()
	if not focus_mode or #picks == 0 then
		APHP.ScrollHud(direction * lines)
		return true
	end
	local target = (focus_index > 0 and focus_index or picks[1]) + direction * lines
	local chosen = direction > 0 and picks[#picks] or picks[1]
	for _, index in ipairs(picks) do
		if direction > 0 and index >= target then
			chosen = index
			break
		end
		if direction < 0 and index <= target then chosen = index end
	end
	focus_index = chosen
	scroll_offset = scroll_offset + direction * lines
	APHP.RefreshHud()
	return true
end

function APHP.StopPadHold()
	EVENT_MANAGER:UnregisterForUpdate(PAD_HOLD_JOB)
	return false
end

local function PadPan(direction)
	if not APHP.IsTimelineShown() then return false end
	APHP.StopPadHold()
	APHP.MoveTimelineCursor(direction)
	local started = GetGameTimeMilliseconds()
	local last = started
	EVENT_MANAGER:RegisterForUpdate(PAD_HOLD_JOB, 0, function()
		local now = GetGameTimeMilliseconds()
		local held, step = now - started, now - last
		last = now
		if held < PAD_HOLD.delay then return end
		if not (focus_mode and APHP.IsTimelineShown() and LibAPH.GetContextMenuDepth() == 0) then return APHP.StopPadHold() end
		local speed = PAD_HOLD.slow + (PAD_HOLD.fast - PAD_HOLD.slow) * zo_clamp((held - PAD_HOLD.delay) / PAD_HOLD.ramp, 0, 1)
		if step > 0 and not APHP.MoveTimelineCursor(direction, speed * step / 1000) then return APHP.StopPadHold() end
	end)
	return true
end

local TIMELINE_IGNORES = { summary = true }
local LOAD_TIMES_IGNORES = { summary = true, timeline = true, pan_left = true, pan_right = true, scan = true }

local PAD_ACTIONS = {
	scan = function()
		if APHP.IsRunning() then APHP.Stop() else APHP.Start() end
		return true
	end,
	menu = function()
		if LoadTimesFront() then return APHP.OpenLoadTimesMenu() end
		if APHP.IsTimelineShown() then return APHP.OpenTimelineMenu() end
		return APHP.OpenHudMenu()
	end,
	summary = function() return APHP.ToggleSummaryView() end,
	timeline = function()
		APHP.ToggleTimeline()
		return true
	end,
	page_up = function() return PadScroll(-1) end,
	page_down = function() return PadScroll(1) end,
	pan_left = function() return PadPan(-1) end,
	pan_right = function() return PadPan(1) end,
	move = function()
		if LoadTimesFront() then
			local moving = not APHP.load_mover:IsMoving()
			if moving then APHP.load_resizer:ToggleGamepadResize(false) end
			APHP.load_mover:ToggleGamepadMove(moving)
			return true
		end
		if not APHP.IsTimelineShown() then
			APHP.ToggleHudMoveMode()
			return true
		end
		local moving = not APHP.timeline_mover:IsMoving()
		if moving then APHP.timeline_resizer:ToggleGamepadResize(false) end
		APHP.timeline_mover:ToggleGamepadMove(moving)
		return true
	end,
	resize = function()
		if LoadTimesFront() then
			local resizing = not APHP.load_resizer:IsResizing()
			if resizing then APHP.load_mover:ToggleGamepadMove(false) end
			APHP.load_resizer:ToggleGamepadResize(resizing)
			return true
		end
		if not APHP.IsTimelineShown() then
			APHP.ToggleHudResizeMode()
			return true
		end
		local resizing = not APHP.timeline_resizer:IsResizing()
		if resizing then APHP.timeline_mover:ToggleGamepadMove(false) end
		APHP.timeline_resizer:ToggleGamepadResize(resizing)
		return true
	end,
	back = function()
		if LoadTimesFront() then
			if APHP.load_mover:IsMoving() then return APHP.load_mover:ToggleGamepadMove(false) or true end
			if APHP.load_resizer:IsResizing() then return APHP.load_resizer:ToggleGamepadResize(false) or true end
			return APHP.HideLoadTimes()
		end
		if APHP.IsTimelineShown() then
			APHP.HideTimeline()
			return true
		end
		return APHP.HideHud()
	end,
}

function APHP.PadAction(name)
	if not focus_mode or not IsPad() or not hud or hud:IsHidden() then return false end
	if LibAPH.GetContextMenuDepth() > 0 then
		if name == "back" then LibAPH.CloseContextMenuLevel() end
		RefreshPadHints()
		return true
	end
	if LoadTimesFront() and LOAD_TIMES_IGNORES[name] then return true end
	if APHP.IsTimelineShown() and TIMELINE_IGNORES[name] then return true end

	local action = PAD_ACTIONS[name]
	if not action then return false end
	local handled = action()
	if focus_mode and hud and not hud:IsHidden() then APHP.RefreshHud() end
	RefreshPadHints()
	return handled and true or false
end

local function GameScreenShown()
	return LibAPH.IsGameScreenShown()
end

local function TakeControlWhenShown()
	local function Begin()
		if hud and not hud:IsHidden() and not focus_mode then APHP.ToggleHudFocus() end
		RefreshPadHints()
	end
	if GameScreenShown() then
		Begin()
		return true
	end
	LibAPH.ScheduleWait(PAD_CONTROL_JOB, GameScreenShown, Begin)
	return true
end

function APHP.EnsureConsoleControl()
	if not IsConsoleUI() or not hud or hud:IsHidden() or focus_mode then return false end
	return TakeControlWhenShown()
end

function APHP.StartPadControl()
	APHP.ShowHud()
	if not GameScreenShown() then SCENE_MANAGER:ShowBaseScene() end
	return TakeControlWhenShown()
end

function APHP.ToggleOwnerExpanded(owner)
	if not owner then return false end
	expanded[owner] = not expanded[owner]
	APHP.RefreshHud()
	return true
end

local function ConfirmWipe(title, body, onConfirm)
	LibAPH.ShowDialogHidingWindows({ function() return hud end, APHP.GetTimelineWindow }, "APHProfiler_WIPE", title, body, {
		{ text = SI_DIALOG_CONFIRM, callback = onConfirm },
		{ text = SI_DIALOG_CANCEL },
	})
end

local function RunChoices(current, onPick, includeThisRun, manage)
	local entries = {}
	if includeThisRun then
		entries[#entries + 1] = {
			text = (current == nil and "|c66FF66" or "") .. SourceLabel(nil) .. (current == nil and "|r" or ""),
			onClick = function() onPick(nil) end,
		}
	end
	local runs = APHP.GetRuns()
	for index = #runs, 1, -1 do
		local run = runs[index]
		local entry = { text = (current == run and "|c66FF66" or "") .. APHP.DescribeRun(run) .. (current == run and "|r" or "") }
		if manage then
			entry.submenu = function() return APHP.ScanChoices(run) end
		else
			entry.onClick = function() onPick(run) end
		end
		entries[#entries + 1] = entry
	end
	if #runs == 0 and not includeThisRun then
		entries[#entries + 1] = { text = APHP.L("NO_SAVED_SCANS_YET") }
	end
	return entries
end

function APHP.SetCompareTop(run)
	compare_a = run
	APHP.RefreshHud()
	return true
end

function APHP.SetCompareBottom(run, explicit)
	compare_b = run
	compare_b_set = explicit ~= false
	APHP.RefreshHud()
	return true
end

function APHP.ClearComparison()
	compare_a = nil
	compare_b = nil
	compare_b_set = false
	APHP.RefreshHud()
	return true
end

function APHP.WipeAllResults()
	local removed = APHP.WipeAllRuns()
	expanded = {}
	APHP.ClearComparison()
	APHP.Print(string.format(APHP.L("WIPED_SAVED_RUN"), removed, removed == 1 and "" or "s"))
	return removed
end

function APHP.WipeLatestResult()
	local wiped = APHP.WipeLastRun()
	APHP.ClearComparison()
	if wiped then APHP.Print(APHP.L("WIPED_THE_MOST_RECENT_SAVED_RUN")) else APHP.Print(APHP.L("NO_SAVED_RUNS_TO_WIPE"), true) end
	return wiped
end

function APHP.DeleteScan(run)
	if not APHP.DeleteRun(run) then return false end
	if compare_a == run then compare_a = nil end
	if compare_b == run then
		compare_b = nil
		compare_b_set = false
	end
	APHP.RefreshHud()
	return true
end

function APHP.ScanChoices(run)
	local top = APHP.GetCompareSources()
	return {
		{ text = top == run and APHP.L("SHOW_SHOWING_NOW") or APHP.L("SHOW"), onClick = function() APHP.SetCompareTop(run) end },
		{ text = APHP.L("RENAME"), onClick = function() APHP.AskRename(run) end },
		{
			text = APHP.Danger(APHP.L("DELETE")),
			onClick = function()
				ConfirmWipe(APHP.L("DELETE_SCAN"), string.format(APHP.L("DELETE_SCAN_BODY"), APHP.DescribeRun(run)), function()
					APHP.DeleteScan(run)
				end)
			end,
		},
	}
end

local function OptionEntries(entries)
	if APHP.IsRunning() then
		entries[#entries + 1] = { text = APHP.L("STOP_RECORDING"), onClick = function() APHP.Stop() end }
		return
	end
	entries[#entries + 1] = { text = APHP.L("START_RECORDING"), onClick = function() APHP.Start() end }
	entries[#entries + 1] = { text = APHP.LengthText(), onClick = function() APHP.AskScanLength() end }
	if APHP.CanScanLoadTimes() then
		entries[#entries + 1] = {
			text = APHP.L("SCAN_LOAD_TIMES"),
			checkbox = true,
			checked = APHP.saved.scan_load_times == true,
			tooltip = APHP.L("SCAN_LOAD_TIMES_TIP"),
			onToggle = function(on)
				APHP.saved.scan_load_times = on and true or false
				if on then APHP.saved.profile_ui_load = false end
			end,
		}
	end
	if APHP.CanProfileUiLoad() then
		entries[#entries + 1] = {
			text = APHP.L("PROFILE_UI_LOAD"),
			checkbox = true,
			checked = APHP.saved.profile_ui_load == true,
			tooltip = APHP.L("PROFILE_UI_LOAD_TIP"),
			onToggle = function(on)
				APHP.saved.profile_ui_load = on and true or false
				if on then APHP.saved.scan_load_times = false end
			end,
		}
	end
end

function APHP.GetComparison()
	local top, bottom = APHP.GetCompareSources()
	return top, bottom
end

local function TimelineEntries(entries)
	if #APHP.TimelineLegendEntries() == 0 then return entries end
	entries[#entries + 1] = {
		text = APHP.L("TIMELINE_SHOW_OR_HIDE"),
		submenu = function() return APHP.TimelineLegendEntries() end,
	}
	entries[#entries + 1] = {
		text = APHP.IsTimelineLog() and APHP.L("TIMELINE_SCALE_LOG") or APHP.L("TIMELINE_SCALE_LINEAR"),
		onClick = function() APHP.SetTimelineLog(not APHP.IsTimelineLog()) end,
	}
	entries[#entries + 1] = {
		text = APHP.L("TIMELINE_ZOOM"),
		submenu = function()
			return {
				{ text = APHP.L("ZOOM_IN_2"), closeOnClick = false, onClick = function() APHP.ZoomTimeline(0.5) end },
				{ text = APHP.L("ZOOM_OUT_2"), closeOnClick = false, onClick = function() APHP.ZoomTimeline(2) end },
				{ text = APHP.L("PAN_LEFT"), closeOnClick = false, onClick = function() APHP.PanTimeline(-0.25) end },
				{ text = APHP.L("PAN_RIGHT"), closeOnClick = false, onClick = function() APHP.PanTimeline(0.25) end },
				{ text = APHP.L("FULL_TIMELINE"), onClick = function() APHP.ResetTimelineZoom() end },
			}
		end,
	}
	return entries
end

function APHP.BuildTimelineMenuEntries()
	local entries = { { text = "Timeline", header = true } }
	TimelineEntries(entries)
	if #entries > 1 then entries[#entries + 1] = { divider = true } end
	entries[#entries + 1] = { text = APHP.L("CLOSE_TIMELINE"), onClick = function() APHP.HideTimeline() end }
	return entries
end

function APHP.OpenTimelineMenu(control)
	local window = APHP.GetTimelineWindow()
	if not window or window:IsHidden() then return false end
	if LibAPH.GetContextMenuDepth() > 0 then
		LibAPH.CloseContextMenu()
		RefreshPadHints()
		return true
	end
	APHP.ShowMenu(control or window, APHP.BuildTimelineMenuEntries, window)
	if focus_mode and IsPad() then LibAPH.MoveContextMenuFocus(1) end
	RefreshPadHints()
	return true
end

function APHP.BuildResultsMenuEntries()
	local top, bottom = APHP.GetCompareSources()
	local entries = {}

	entries[#entries + 1] = { text = "APH-Profiler", header = true }
	OptionEntries(entries)
	entries[#entries + 1] = { divider = true }
	entries[#entries + 1] = {
		text = APHP.L("SHOWING") .. SourceLabel(top),
		submenu = function()
			return RunChoices(top, function(run) APHP.SetCompareTop(run) end, true, true)
		end,
	}
	entries[#entries + 1] = {
		text = APHP.L("COMPARE_AGAINST") .. (bottom and APHP.DescribeRun(bottom) or "nothing"),
		submenu = function()
			local choices = RunChoices(bottom, function(run) APHP.SetCompareBottom(run, true) end, top ~= nil)
			table.insert(choices, 1, {
				text = "Nothing",
				onClick = function() APHP.SetCompareBottom(nil, true) end,
			})
			return choices
		end,
	}
	entries[#entries + 1] = {
		text = APHP.L("CLEAR_COMPARISON"),
		onClick = function() APHP.ClearComparison() end,
	}

	entries[#entries + 1] = { divider = true }
	if not IsConsoleUI() then entries[#entries + 1] = { text = "Export", onClick = function() APHP.ShowExport() end } end
	entries[#entries + 1] = {
		text = APHP.saved.hud_locked and APHP.L("UNLOCK_POSITION") or APHP.L("LOCK_POSITION"),
		onClick = function()
			APHP.saved.hud_locked = not APHP.saved.hud_locked
			APHP.ApplyHudLock()
		end,
	}
	entries[#entries + 1] = {
		text = APHP.Danger(APHP.L("WIPE_LAST_RUN_2")),
		onClick = function()
			ConfirmWipe(APHP.L("WIPE_LAST_RUN_3"), APHP.L("THROW_AWAY_THE_MOST_RECENT_SAVED"), function()
				APHP.WipeLatestResult()
			end)
		end,
	}
	entries[#entries + 1] = {
		text = APHP.Danger(APHP.L("WIPE_ALL_RESULTS_2")),
		onClick = function()
			ConfirmWipe(APHP.L("WIPE_ALL_RESULTS_3"), APHP.L("THROW_AWAY_EVERY_SAVED_SCAN_AND"), function()
				APHP.WipeAllResults()
			end)
		end,
	}
	entries[#entries + 1] = { divider = true }
	entries[#entries + 1] = {
		text = APHP.IsTimelineShown() and APHP.L("HIDE_TIMELINE_2") or "Timeline",
		onClick = function() APHP.ToggleTimeline() end,
	}
	if APHP.IsTimelineShown() then TimelineEntries(entries) end
	entries[#entries + 1] = {
		text = view == "summary" and "Back to results" or "Summary",
		onClick = function() APHP.ToggleSummaryView() end,
	}
	if view == "summary" then
		entries[#entries + 1] = {
			text = APHP.L("SUMMARY_SHOW_OR_HIDE"),
			submenu = function()
				return {
					{ text = LibAPH.StripColors(APHP.L("GAME_UI")), checkbox = true, checked = APHP.saved.summary_hide_game_ui ~= true,
						onToggle = function(on) APHP.saved.summary_hide_game_ui = not on APHP.RefreshHud() end },
					{ text = LibAPH.StripColors(APHP.L("LUA_GARBAGE_COLLECTOR")), checkbox = true, checked = APHP.saved.summary_hide_gc ~= true,
						onToggle = function(on) APHP.saved.summary_hide_gc = not on APHP.RefreshHud() end },
				}
			end,
		}
	end
	entries[#entries + 1] = {
		text = APHP.IsLoadTimesShown() and APHP.L("CLOSE_LOAD_TIMES") or APHP.L("OPEN_LOAD_TIMES"),
		onClick = function() APHP.ToggleLoadTimes() end,
	}
	if LibAPH.SettingsMenuEntries and APHP.SettingsControls then
		entries[#entries + 1] = { divider = true }
		entries[#entries + 1] = {
			text = APHP.L("ADVANCED_OPTIONS"),
			submenu = function()
				return LibAPH.SettingsMenuEntries(APHP.SettingsControls(), {
					id = "APHProfiler", rangeText = APHP.L("SETTING_RANGE"), askText = APHP.AskText,
					confirm = function(_, title, body, onConfirm) ConfirmWipe(title, body, onConfirm) end,
				})
			end,
		}
	end
	entries[#entries + 1] = { divider = true }
	entries[#entries + 1] = { text = "Close", onClick = function() APHP.HideHud() end }
	return entries
end

local function ButtonWidth()
	return IsPad() and 90 or 75
end

local function ButtonHeight()
	return IsPad() and 28 or 25
end

local function OnWheel(_, delta)
	APHP.ScrollHud(-delta * WHEEL_LINES)
end

local function AcquireRowLabel(index)
	local label = row_labels[index]
	if label then return label end

	label = WINDOW_MANAGER:CreateControl(HUD_NAME .. "Row" .. index, hud, CT_LABEL)
	label:SetColor(0.8, 0.8, 0.8, 1)
	label:SetVerticalAlignment(TEXT_ALIGN_TOP)
	label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
	label:SetMaxLineCount(1)
	label:SetMouseEnabled(true)
	label:SetHandler("OnMouseDown", function(self, button)
		if button ~= MOUSE_BUTTON_INDEX_LEFT then return end
		self.aphp_press_left, self.aphp_press_top = hud:GetLeft(), hud:GetTop()
		hud:StartMoving()
	end)
	label:SetHandler("OnMouseUp", function(self, button, upInside)
		if button == MOUSE_BUTTON_INDEX_LEFT then
			hud:StopMovingOrResizing()
			local pressed = self.aphp_press_left ~= nil
			local moved = pressed and
				(self.aphp_press_left ~= hud:GetLeft() or self.aphp_press_top ~= hud:GetTop())
			self.aphp_press_left, self.aphp_press_top = nil, nil
			if moved then
				SaveHudPosition()
				return
			end
		end
		if not upInside then return end
		if button == MOUSE_BUTTON_INDEX_RIGHT then
			APHP.ShowMenu(self, APHP.BuildResultsMenuEntries, hud)
			return
		end
		APHP.ToggleOwnerExpanded(self.aphp_owner)
	end)
	label:SetHandler("OnMouseWheel", OnWheel)
	label:SetHandler("OnMouseEnter", function(self)
		local line = self.aphp_line
		if line and line.tip then APHP.ShowTip(self, line.tip(), hud) end
	end)
	label:SetHandler("OnMouseExit", function() APHP.HideTip() end)
	row_labels[index] = label
	return label
end

local function MeasureLine(text, font)
	measure_lbl:SetFont(font)
	measure_lbl:SetText(text)
	local w, h = measure_lbl:GetTextDimensions()
	return w or 0, h or 0
end

local function Inset()
	return PAD_X < RESIZE_HANDLE and RESIZE_HANDLE or PAD_X
end

local function TopInset()
	return PAD_Y < RESIZE_HANDLE and RESIZE_HANDLE or PAD_Y
end

local function HeaderWidth()
	local title_w = MeasureLine(TITLE_TEXT, FontForSize(16))
	return title_w + STATUS_RESERVE + ButtonWidth() * HUD_BUTTONS + HEADER_BTN_GAP * HUD_BUTTONS + CLOSE_BTN_SIZE + BUTTON_GAP
end

local function NaturalSize()
	local font = FontForSize(BASE_FONT_SIZE)
	local width, height = 0, 0

	for _, line in ipairs(hud_lines) do
		local line_w, line_h = MeasureLine(line.text, font)
		if not line.detail and line_w > width then width = line_w end
		height = height + line_h
	end
	return width, height
end

local function FontSizeFor(width, natural_w, height, natural_h)
	if not APHP.saved.hud_w or natural_w <= 0 then return BASE_FONT_SIZE end
	local usable_w = width - Inset() * 2 - EXTRA_W
	local ratio = usable_w / natural_w
	if IsPad() and natural_h and natural_h > 0 then
		local usable_h = height - TopInset() * 2 - HEADER_H - EXTRA_H
		ratio = math.min(ratio, math.max(usable_h / natural_h, 1))
	end
	local size = math.floor(BASE_FONT_SIZE * ratio + 0.5)
	if size < MIN_FONT_SIZE then size = MIN_FONT_SIZE end
	if size > MAX_FONT_SIZE then size = MAX_FONT_SIZE end
	return size
end

local function ClampScroll()
	if scroll_offset > max_scroll then scroll_offset = max_scroll end
	if scroll_offset < 0 then scroll_offset = 0 end
end

local function KeepFocusVisible(visible)
	if not focus_mode or focus_index < 1 or visible < 1 then return end
	if focus_index - 1 < scroll_offset then
		scroll_offset = focus_index - 1
	elseif focus_index > scroll_offset + visible then
		scroll_offset = focus_index - visible
	end
end

local function LayoutScrollbar(top, content_h, visible, total)
	if not scroll_track then return end
	local scrollable = max_scroll > 0
	scroll_track:SetHidden(not scrollable)
	scroll_thumb:SetHidden(not scrollable)
	scroll_grab:SetHidden(not scrollable)
	APHP.hud_scrollable = scrollable
	if not scrollable then return end

	local track_top, track_h = top, content_h
	scroll_track:ClearAnchors()
	scroll_track:SetAnchor(TOPRIGHT, hud, TOPRIGHT, -Inset(), track_top)
	scroll_track:SetDimensions(SCROLLBAR_W, track_h)

	local thumb_h = math.max(track_h * visible / total, MIN_THUMB_H)
	if thumb_h > track_h then thumb_h = track_h end
	local thumb_y = (track_h - thumb_h) * scroll_offset / max_scroll
	scroll_thumb:ClearAnchors()
	scroll_thumb:SetAnchor(TOPRIGHT, scroll_track, TOPRIGHT, 0, thumb_y)
	scroll_thumb:SetDimensions(SCROLLBAR_W, thumb_h)
	scroll_grab:ClearAnchors()
	scroll_grab:SetAnchor(TOPRIGHT, scroll_track, TOPRIGHT, 0, 0)
	scroll_grab:SetDimensions(GRAB_W, track_h)
	APHP.hud_track_h, APHP.hud_thumb_h = track_h, thumb_h
end

local function AcquireRowBackground(index)
	local bg = row_bgs[index]
	if bg then return bg end
	bg = WINDOW_MANAGER:CreateControl(HUD_NAME .. "RowBG" .. index, hud, CT_TEXTURE)
	bg:SetMouseEnabled(false)
	bg:SetDrawLevel(1)
	row_bgs[index] = bg
	return bg
end

local function LayoutRows()
	local inset, top = Inset(), TopInset() + HEADER_H
	local min_width = math.max(IsConsoleUI() and MIN_WIDTH_CONSOLE or MIN_WIDTH_PC, HeaderWidth() + inset * 2)
	APHP.hud_min_width = min_width

	local natural_w, natural_h = NaturalSize()
	local max_fit_h = GuiRoot:GetHeight() * MAX_FIT_HEIGHT_SHARE
	APHP.hud_fit_width = math.max(natural_w + inset * 2 + EXTRA_W, min_width)
	APHP.hud_fit_height = zo_clamp(natural_h + top + TopInset() + EXTRA_H, MIN_HEIGHT, math.max(max_fit_h, MIN_HEIGHT))

	local width = APHP.saved.hud_w or APHP.hud_fit_width
	local height = APHP.saved.hud_h or APHP.hud_fit_height
	if width < min_width then width = min_width end
	if height < MIN_HEIGHT then height = MIN_HEIGHT end

	local size = FontSizeFor(width, natural_w, height, natural_h)
	APHP.saved.hud_font_size = size

	local font = FontForSize(size)
	local content_w = width - inset * 2
	if content_w < 1 then content_w = 1 end
	local content_h = height - top - TopInset()
	APHP.hud_body_top = top

	local _, line_h = MeasureLine("Ag", font)
	if line_h <= 0 then line_h = size + 4 end
	local visible = math.max(math.floor(content_h / line_h), 1)
	max_scroll = math.max(#hud_lines - visible, 0)
	KeepFocusVisible(visible)
	ClampScroll()

	local bar_room = max_scroll > 0 and (SCROLLBAR_W + SCROLLBAR_GAP) or 0

	local shown = 0
	for slot = 1, visible do
		local index = scroll_offset + slot
		local line = hud_lines[index]
		local label = AcquireRowLabel(slot)
		local bg = AcquireRowBackground(slot)
		if not line then
			label:SetHidden(true)
			label.aphp_owner = nil
			bg:SetHidden(true)
		else
			label:SetFont(font)
			label:SetText(line.text)
			label.aphp_owner = line.owner
			label.aphp_line = line
			if focus_mode and index == focus_index then
				label:SetColor(1, 1, 0.4, 1)
			else
				label:SetColor(0.8, 0.8, 0.8, 1)
			end
			local row_w = content_w - bar_room
			if row_w < 1 then row_w = 1 end
			local row_y = top + (slot - 1) * line_h
			label:ClearAnchors()
			label:SetAnchor(TOPLEFT, hud, TOPLEFT, inset, row_y)
			label:SetDimensions(row_w, line_h)
			LibAPH.FitLabelText(label, line.text, { font = font, width = row_w })
			label:SetDrawLevel(2)
			label:SetHidden(false)
			bg:ClearAnchors()
			bg:SetAnchor(TOPLEFT, hud, TOPLEFT, inset - 2, row_y)
			bg:SetDimensions(row_w + 4, line_h)
			LibAPH.StyleRowBackground(bg, index, line.section)
			shown = shown + 1
		end
	end
	APHP.hud_shown_lines = shown
	APHP.hud_visible_rows = visible

	for slot = visible + 1, #row_labels do
		row_labels[slot]:SetHidden(true)
		row_labels[slot].aphp_owner = nil
		if row_bgs[slot] then row_bgs[slot]:SetHidden(true) end
	end

	hud:SetDimensions(width, height)
	LayoutScrollbar(top, content_h, visible, #hud_lines)
	RefreshPadHints()

	if focus_mode then
		local slot = focus_index - scroll_offset
		local line = hud_lines[focus_index]
		if HudInFront() and line and line.tip and row_labels[slot] then
			APHP.ShowTip(row_labels[slot], line.tip(), hud)
		else
			APHP.HideTip(hud)
		end
	end
end

function APHP.GetHudScroll() return scroll_offset, max_scroll end

function APHP.ScrollHud(lines)
	if not hud then return false end
	local was = scroll_offset
	scroll_offset = scroll_offset + lines
	ClampScroll()
	if scroll_offset == was then return false end
	LayoutRows()
	return true
end

local function UpdateScanButton()
	if not scan_btn then return end
	scan_btn:SetText(APHP.IsRunning() and "Stop" or "Scan")
	if summary_btn then summary_btn:SetText(view == "summary" and "Results" or "Summary") end
	local font = IsPad() and "ZoFontGamepad18" or "ZoFontGameSmall"
	for _, btn in ipairs({ scan_btn, summary_btn, timeline_btn }) do LibAPH.FitButtonText(btn, { font = font }) end
end

function APHP.ApplyHudLock()
	if not hud then return false end
	hud:SetMovable(not APHP.saved.hud_locked)
	return true
end

function SaveHudPosition()
	if not hud then return false end
	APHP.saved.hud_x, APHP.saved.hud_y = hud:GetLeft(), hud:GetTop()
	return true
end

function APHP.ResetHudSize()
	APHP.saved.hud_w, APHP.saved.hud_h = nil, nil
	APHP.saved.hud_font_size = BASE_FONT_SIZE
	APHP.RefreshHud()
	return true
end

local function OnHudResized()
	if not hud then return end
	APHP.saved.hud_w, APHP.saved.hud_h = hud:GetWidth(), hud:GetHeight()
	APHP.RefreshHud()
end

local function RecordingStatus()
	local clock = APHP.FormatClock((APHP.GetRecordingElapsedMs() or 0) / 1000)
	if APHP.IsTimedScan() then clock = clock .. " / " .. APHP.FormatClock(APHP.ScanSeconds()) end
	local text = string.format(APHP.L("REC"), clock)
	if not APHP.IsTimedScan() then text = text .. "  " .. APHP.L("OPEN_RESULTS_TO_STOP") end
	return text
end

local scan_line

local function ScanLine()
	if scan_line == nil then
		scan_line = LibAPH.CreateStatusLine and LibAPH.CreateStatusLine(SCAN_LINE_NAME, {
			font = IsConsoleUI() and "ZoFontGamepad27" or "ZoFontGameMedium",
			width = IsConsoleUI() and 1100 or 900,
			align = TEXT_ALIGN_CENTER,
			point = TOP, relativeTo = "ZO_CompassFrame", relativePoint = BOTTOM,
			offsetX = 0, offsetY = 8, consoleOffsetX = 0, consoleOffsetY = 8,
			stack = "compass", order = SCAN_LINE_ORDER,
		}) or false
	end
	return scan_line or nil
end

function APHP.ScanStatusOn()
	return APHP.saved.scan_status ~= false and LibAPH.CreateStatusLine ~= nil
end

local scan_text = ""

function APHP.SetScanStatus(text)
	scan_text = text or ""
	APHP.SetHudStatus(text)
	local busy = text and text ~= "" and (APHP.IsRunning() or APHP.IsParsing())
	if busy and APHP.ScanStatusOn() then
		ScanLine():Set(SCAN_LINE_TITLE .. text)
	elseif scan_line then
		scan_line:Hide()
	end
end

function APHP.RefreshScanStatus()
	return APHP.SetScanStatus(scan_text)
end

function APHP.GetScanStatusText()
	return scan_line and scan_line:GetText() or nil
end

local reopen_after_scan = false

function APHP.StepAsideForScan(ends_by_itself)
	if not (APHP.ScanStatusOn() and ends_by_itself and hud and not hud:IsHidden()) then return false end
	reopen_after_scan = true
	APHP.HideHud()
	return true
end

function APHP.KeepAsideUntilScanDone()
	if not APHP.ScanStatusOn() then return false end
	reopen_after_scan = true
	return true
end

function APHP.ReturnAfterScan(open)
	local back = reopen_after_scan
	reopen_after_scan = false
	if open or back then
		APHP.ShowHud()
		return true
	end
	APHP.RefreshHud()
	return false
end

function APHP.OnRecordingStarted()
	EVENT_MANAGER:RegisterForUpdate(TIMER_NAMESPACE, TIMER_MS, function()
		if APHP.IsRunning() then APHP.SetScanStatus(RecordingStatus()) end
	end)
	APHP.SetScanStatus(RecordingStatus())
	UpdateScanButton()
	APHP.StepAsideForScan(true)
end

function APHP.OnRecordingStopped()
	EVENT_MANAGER:UnregisterForUpdate(TIMER_NAMESPACE)
	APHP.SetScanStatus("")
	UpdateScanButton()
end

function APHP.RestoreHudStatus()
	return APHP.SetHudStatus(APHP.IsRunning() and RecordingStatus() or "")
end

function APHP.SetHudStatus(text)
	if not status_lbl then return false end
	status_lbl:SetText(text or "")
	return true
end

local function AnchorHud()
	hud:ClearAnchors()
	if APHP.saved.hud_x and APHP.saved.hud_y then
		hud:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, APHP.saved.hud_x, APHP.saved.hud_y)
	else
		hud:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, 50, 400)
	end
end

local function BuildHud()
	hud = WINDOW_MANAGER:CreateControl(HUD_NAME, GuiRoot, CT_TOPLEVELCONTROL)
	hud:SetClampedToScreen(true)
	hud:SetMouseEnabled(true)
	hud:SetMovable(not APHP.saved.hud_locked)
	hud:SetDrawTier(DT_HIGH)
	hud:SetDrawLayer(DL_OVERLAY)
	hud:SetDrawLevel(9000)
	hud:SetHidden(true)
	hud:SetHandler("OnMoveStop", function() SaveHudPosition() end)
	hud:SetHandler("OnMouseUp", function(control, button, upInside)
		if upInside and button == MOUSE_BUTTON_INDEX_RIGHT then
			APHP.ShowMenu(control, APHP.BuildResultsMenuEntries, hud)
		end
	end)

	measure_lbl = WINDOW_MANAGER:CreateControl(HUD_NAME .. "Measure", GuiRoot, CT_LABEL)
	measure_lbl:SetAlpha(0)
	measure_lbl:SetMouseEnabled(false)
	measure_lbl:SetDrawLayer(DL_BACKGROUND)
	measure_lbl:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, 0, 0)
	measure_lbl:SetDimensions(MEASURE_W, MEASURE_H)

	LibAPH.ApplyPanelBackdrop(hud, HUD_NAME .. "BG", LibAPH.THEME.BG_HUD)

	LibAPH.CreateHeaderStrip(hud, HUD_NAME .. "Header", TopInset() + HEADER_H - 4)

	title_lbl = WINDOW_MANAGER:CreateControl(HUD_NAME .. "Title", hud, CT_LABEL)
	title_lbl:SetFont(FontForSize(16))
	title_lbl:SetText(TITLE_TEXT)
	title_lbl:SetAnchor(TOPLEFT, hud, TOPLEFT, Inset(), TopInset() + 2)

	hud:SetHandler("OnMouseWheel", OnWheel)

	scroll_track = WINDOW_MANAGER:CreateControl(HUD_NAME .. "ScrollTrack", hud, CT_TEXTURE)
	scroll_track:SetColor(1, 1, 1, 0.12)
	scroll_track:SetHidden(true)

	scroll_thumb = WINDOW_MANAGER:CreateControl(HUD_NAME .. "ScrollThumb", hud, CT_TEXTURE)
	scroll_thumb:SetColor(0.8, 0.8, 0.8, 0.7)
	scroll_thumb:SetDrawLevel(5)
	scroll_thumb:SetHidden(true)

	scroll_grab = WINDOW_MANAGER:CreateControl(HUD_NAME .. "ScrollGrab", hud, CT_CONTROL)
	scroll_grab:SetMouseEnabled(true)
	scroll_grab:SetDrawLevel(6)
	scroll_grab:SetHidden(true)
	scroll_grab:SetHandler("OnMouseWheel", OnWheel)
	local function DragUpdate(grab)
		local drag = grab.aphp_drag
		if not drag then return end
		local _, now_y = GetUIMousePosition()
		local travel = (APHP.hud_track_h or 1) - (APHP.hud_thumb_h or 0)
		if travel <= 0 or max_scroll <= 0 then return end
		local target = drag.offset + math.floor((now_y - drag.y) / travel * max_scroll + 0.5)
		if target ~= scroll_offset then APHP.ScrollHud(target - scroll_offset) end
	end
	scroll_grab:SetHandler("OnMouseDown", function(grab, button)
		if button ~= MOUSE_BUTTON_INDEX_LEFT then return end
		local _, y = GetUIMousePosition()
		if y < scroll_thumb:GetTop() or y > scroll_thumb:GetBottom() then
			local travel = (APHP.hud_track_h or 1) - (APHP.hud_thumb_h or 0)
			if travel > 0 and max_scroll > 0 then
				local wanted = (y - scroll_track:GetTop() - (APHP.hud_thumb_h or 0) / 2) / travel * max_scroll
				wanted = math.max(0, math.min(max_scroll, math.floor(wanted + 0.5)))
				APHP.ScrollHud(wanted - scroll_offset)
			end
		end
		grab.aphp_drag = { y = y, offset = scroll_offset }
		grab:SetHandler("OnUpdate", DragUpdate)
	end)
	scroll_grab:SetHandler("OnMouseUp", function(grab)
		grab.aphp_drag = nil
		grab:SetHandler("OnUpdate", nil)
	end)

	status_lbl = WINDOW_MANAGER:CreateControl(HUD_NAME .. "Status", hud, CT_LABEL)
	status_lbl:SetFont(RowFont())
	status_lbl:SetColor(0.8, 0.8, 0.8, 1)
	status_lbl:SetAnchor(LEFT, title_lbl, RIGHT, 12, 0)
	status_lbl:SetText("")

	local function HeaderButton(suffix, text, onClick)
		local btn = WINDOW_MANAGER:CreateControlFromVirtual(HUD_NAME .. suffix, hud, "ZO_DefaultButton")
		btn:SetDimensions(ButtonWidth(), ButtonHeight())
		btn:SetFont(IsPad() and "ZoFontGamepad18" or "ZoFontGameSmall")
		btn:SetDrawLevel(20)
		btn:SetText(text)
		btn:SetHandler("OnClicked", onClick)
		return btn
	end
	summary_btn = HeaderButton("SummaryBtn", "Summary", function() APHP.ToggleSummaryView() end)
	local close_btn = LibAPH.CreateThemedCloseButton(hud, HUD_NAME .. "CloseBtn", function() APHP.HideHud() end,
		Inset(), TopInset() + (ButtonHeight() - CLOSE_BTN_SIZE) / 2)
	close_btn:SetDrawLevel(20)
	summary_btn:SetAnchor(TOPRIGHT, close_btn, TOPLEFT, -HEADER_BTN_GAP, -(ButtonHeight() - CLOSE_BTN_SIZE) / 2)
	timeline_btn = HeaderButton("TimelineBtn", "Timeline", function() APHP.ToggleTimeline() end)
	timeline_btn:SetAnchor(RIGHT, summary_btn, LEFT, -HEADER_BTN_GAP, 0)
	scan_btn = HeaderButton("ScanBtn", "Scan", function()
		if APHP.IsRunning() then APHP.Stop() else APHP.Start() end
		UpdateScanButton()
	end)
	scan_btn:SetAnchor(RIGHT, timeline_btn, LEFT, -HEADER_BTN_GAP, 0)
	UpdateScanButton()

	LibAPH.MakeWindowResizable(hud, {
		handleSize = RESIZE_HANDLE,
		minWidth = math.max(MIN_WIDTH_PC, HeaderWidth() + Inset() * 2),
		minHeight = MIN_HEIGHT,
		onResizing = OnHudResized,
		onResizeStop = OnHudResized,
	})

	APHP.hud_mover = LibAPH.CreateGamepadMover(hud)
	APHP.hud_mover:RegisterCallback(APHP.name .. "_Hud", 2, function(pos)
		if type(pos.left) == "number" then APHP.saved.hud_x = pos.left end
		if type(pos.top) == "number" then APHP.saved.hud_y = pos.top end
		if move_mode then
			move_mode = false
			APHP.RestoreHudStatus()
		end
		RefreshPadHints()
	end)

	hud_resizer = LibAPH.CreateGamepadResizer(hud, {
		minWidth = function() return APHP.hud_min_width or MIN_WIDTH_CONSOLE end,
		minHeight = MIN_HEIGHT,
		onResizing = function()
			OnHudResized()
			RefreshPadHints()
		end,
		onResizeStop = function()
			OnHudResized()
			APHP.RestoreHudStatus()
			RefreshPadHints()
		end,
	})

	if LibAPH.CreatePadHintBar then pad_hints = LibAPH.CreatePadHintBar(HUD_NAME .. "PadHints", { parent = hud, above = { APHP.GetTimelineWindow, APHP.GetLoadTimesWindow } }) end

	SCENE_MANAGER:RegisterCallback("SceneStateChanged", function(scene, _, new_state)
		local name = scene and scene:GetName()
		local game_screen = name == "hud" or name == "hudui"
		if new_state == SCENE_SHOWN and game_screen then
			APHP.EnsureConsoleControl()
			return
		end
		if new_state ~= SCENE_SHOWING or not focus_mode or not IsPad() then return end
		if not game_screen then APHP.ToggleHudFocus() end
	end)

	AnchorHud()
	APHP.hud_sticky = LibAPH.CreateStickyFragment(hud, { "hud", "hudui" })
	APHP.hud_fragment = APHP.hud_sticky.fragment
	return hud
end

function APHP.RefreshHud()
	if not hud then return false end
	hud_lines = BuildHudLines()
	LayoutRows()
	UpdateScanButton()
	APHP.RefreshTimeline()
	return true
end

function APHP.ShowHud()
	if not hud then BuildHud() end
	APHP.RefreshHud()
	APHP.hud_sticky:Open()
	APHP.saved.show_hud = true
	APHP.EnsureConsoleControl()
	return true
end

function APHP.HideHud()
	if not hud then return false end
	if move_mode then APHP.ToggleHudMoveMode() end
	if hud_resizer then hud_resizer:ToggleGamepadResize(false) end
	local waiting = LibAPH.GetScheduledJob(PAD_CONTROL_JOB)
	if waiting then waiting:Cancel() end
	if focus_mode then
		focus_mode = false
		focus_index = 0
		SetFocusLayer(false)
		LibAPH.CloseContextMenu()
	end
	APHP.hud_sticky:Close()
	APHP.saved.show_hud = false
	APHP.HideTip()
	APHP.HideTimeline()
	if APHP.HideLoadTimes then APHP.HideLoadTimes() end
	return true
end

function APHP.ToggleHud()
	if hud and not hud:IsHidden() then return APHP.HideHud() end
	return APHP.ShowHud()
end

function APHP.ShowExport()
	local text = APHP.BuildExportText()
	if not text then
		APHP.Print(APHP.L("NOTHING_TO_EXPORT_YET"), true)
		return false
	end
	export_box = export_box or LibAPH.CreateCopyTextBox({
		name = "APHProfilerExportBox",
		titleText = "|c9CD04CAPH-Profiler|r Export",
	})
	export_box:Show(text)
	return true
end
