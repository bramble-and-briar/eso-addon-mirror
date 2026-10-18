--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

local FG = APHFPSGraphCore
local Summary = {}
FG.Summary = Summary

local floor = math.floor
local THEME = LibAPH.THEME

local NAME = "APHFPSGraphSummary"
local HEADER_H = 28
local PAD = 10
local FONT_SIZE = 14
local MIN_FONT, MAX_FONT = 10, 30
local LABEL_W = 170
local VALUE_W = 150
local MIN_SCALE, MAX_SCALE = 0.75, 2.2
local FONT_FACE = IsConsoleUI() and "$(GAMEPAD_MEDIUM_FONT)" or "$(BOLD_FONT)"
local TITLE_BAR = { 0, 0, 0, 0.92 }
local COMPARE_COLOR = { 1, 1, 1 }
local ELSEWHERE_COLOR = { 0.35, 0.68, 1 }
local SCREEN_EDGE = 20

local ROWS = {
	{ section = "SECTION_RUN" },
	{ "SUM_LENGTH", "seconds", "time" },
	{ "SUM_FRAMES", "frames", "count" },
	{ "SUM_TARGET", "target_fps", "count" },
	{ section = "SECTION_FPS" },
	{ "SUM_AVG_FPS", "avg_fps", "fps" },
	{ "SUM_MEDIAN_FPS", "median_fps", "fps" },
	{ "SUM_LOW1", "low1_fps", "fps" },
	{ "SUM_LOW01", "low01_fps", "fps" },
	{ "SUM_LOWEST_FPS", "lowest_fps", "fps" },
	{ "SUM_HIGHEST_FPS", "highest_fps", "fps" },
	{ section = "SECTION_FRAME_TIME" },
	{ "SUM_AVG_MS", "avg_ms", "ms" },
	{ "SUM_P50_MS", "p50_ms", "ms" },
	{ "SUM_P95_MS", "p95_ms", "ms" },
	{ "SUM_P99_MS", "p99_ms", "ms" },
	{ "SUM_P999_MS", "p999_ms", "ms" },
	{ "SUM_MAX_MS", "max_ms", "ms" },
	{ "SUM_JITTER", "jitter_ms", "plain" },
	{ section = "SECTION_HITCHES" },
	{ "SUM_SLOW", "slow_frames", "slow" },
	{ "SUM_STUTTERS", "stutters", "lower" },
	{ "SUM_STUTTER_TIME", "stutter_total_ms", "total" },
	{ section = "SECTION_PING" },
	{ "SUM_PING_AVG", "ping_avg", "ping" },
	{ "SUM_PING_MIN", "ping_min", "ping" },
	{ "SUM_PING_MAX", "ping_max", "ping" },
	{ "SUM_PING_JITTER", "ping_jitter", "plain" },
	{ "SUM_PING_WARN", "ping_warn", "count" },
	{ section = "SECTION_LOADS", loads = true },
	{ "SUM_LOADS", "loads", "count", loads = true },
	{ "SUM_LOAD_TIME", "load_s", "secs", loads = true },
	{ "SUM_LOAD_LONGEST", "load_max", "secs", loads = true },
	{ "SUM_RELOADS", "reloads", "count", loads = true },
	{ "SUM_RELOAD_TIME", "reload_s", "secs", loads = true },
	{ "SUM_RELOAD_LONGEST", "reload_max", "secs", loads = true },
	{ section = "SECTION_WINDOWS", windows = true },
	{ "SUM_WINDOW_OPEN", "window_s", "secs", windows = true },
	{ "SUM_WINDOW_KB", "window_kbs", "kbs", windows = true },
}
Summary.ROWS = ROWS

local LOWER_IS_BETTER = { ms = true, plain = true, slow = true, lower = true, total = true, ping = true, secs = true, kbs = true }

local win, title, sticky, position, mover, resizer
local cells = {}
local built = false
local scale = 1
local resizing = false

local function Font()
	return FONT_FACE .. "|" .. zo_clamp(zo_round(FONT_SIZE * scale), MIN_FONT, MAX_FONT) .. "|soft-shadow-thin"
end

local function Saved() return FG.saved end

local function Label(parent, suffix, align)
	local label = WINDOW_MANAGER:CreateControl(NAME .. suffix, parent, CT_LABEL)
	label:SetFont(Font())
	label:SetColor(THEME.TEXT[1], THEME.TEXT[2], THEME.TEXT[3], 1)
	label:SetMaxLineCount(1)
	label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
	if align then label:SetHorizontalAlignment(align) end
	return label
end

function Summary.Source()
	if FG.view.show then return FG.view.show end
	return FG.Sampler.RecordingStats() or FG.Sampler.SessionStats()
end

function Summary.SourceName(run)
	if run then return (run.name or GetDateStringFromTimestamp(run.when or 0)) .. "  " .. FG.FormatDuration(run.seconds or 0) end
	if FG.Sampler.IsRecording() then return FG.L("RECORDING") end
	return FG.L("THIS_RUN")
end

function Summary.FieldText(kind, run, key)
	local value = run[key]
	if value == nil then return "" end
	local G = FG.Graph
	local target = run.target_fps or Saved().target_fps
	if kind == "time" then return FG.FormatDuration(value) end
	if kind == "count" then return tostring(floor(value + 0.5)) end
	if kind == "fps" then return G.FpsText(value, target) end
	if kind == "ms" then return G.MsText(value, target) end
	if kind == "plain" then return G.Fmt(value, 1) end
	if kind == "secs" then return FG.L("SECONDS_VALUE", G.Fmt(value, 1)) end
	if kind == "kbs" then return FG.L("KB_PER_S_VALUE", G.Fmt(value, 1)) end
	if kind == "ping" then return FG.L("MS_VALUE", G.PingText(value, run.ping_warn or Saved().ping_warn_ms)) end
	if kind == "total" then return G.Tint(FG.L("MS_VALUE", G.Fmt(value)), value > 0 and G.BAD or G.GOOD) end
	if kind == "slow" then
		local text = tostring(floor(value + 0.5))
		if run.slow_pct then text = text .. " (" .. G.Fmt(run.slow_pct, 1) .. "%)" end
		return G.Tint(text, value > 0 and G.BAD or G.GOOD)
	end
	return G.Tint(tostring(floor(value + 0.5)), value > 0 and G.BAD or G.GOOD)
end

function Summary.DeltaText(kind, value, other)
	if value == nil or other == nil or kind == "time" or kind == "count" then return "" end
	local diff = value - other
	if math.abs(diff) < 0.05 then return "" end
	local better
	if LOWER_IS_BETTER[kind] then better = diff < 0 else better = diff > 0 end
	local G = FG.Graph
	return " " .. G.Tint((diff > 0 and "+" or "") .. G.Fmt(diff, 1), better and G.GOOD or G.BAD)
end

local function HasLoads(run)
	return run ~= nil and (run.loads ~= nil or run.reloads ~= nil)
end

local function HasWindows(run)
	return run ~= nil and run.window_s ~= nil
end

function Summary.Lines()
	local shown, cmp = Summary.Source(), FG.view.compare
	local loads = HasLoads(shown) or HasLoads(cmp)
	local windows = HasWindows(shown) or HasWindows(cmp)
	local lines = { { "", FG.Graph.Tint(Summary.SourceName(FG.view.show), THEME.ACCENT),
		cmp and FG.Graph.Tint(Summary.SourceName(cmp), COMPARE_COLOR) or "" } }
	local shown_note, shown_elsewhere = nil, nil
	if FG.view.show then shown_note, shown_elsewhere = FG.SealNote(FG.view.show) end
	local cmp_note, cmp_elsewhere = nil, nil
	if cmp then cmp_note, cmp_elsewhere = FG.SealNote(cmp) end
	if shown_note or cmp_note then
		local G = FG.Graph
		lines[#lines + 1] = { "", shown_note and G.Tint(shown_note, shown_elsewhere and ELSEWHERE_COLOR or G.BAD) or "",
			cmp_note and G.Tint(cmp_note, cmp_elsewhere and ELSEWHERE_COLOR or G.BAD) or "" }
	end
	for _, row in ipairs(ROWS) do
		local show = (loads or not row.loads) and (windows or not row.windows)
		if show and row.section then
			lines[#lines + 1] = { FG.Graph.Tint(FG.L(row.section), THEME.ACCENT), "", "", section = true }
		elseif show then
			local label, key, kind = FG.L(row[1]), row[2], row[3]
			if key == "stutters" then label = FG.L("SUM_STUTTERS_AT", shown.stutter_ms or Saved().stutter_ms) end
			local value = Summary.FieldText(kind, shown, key)
			if cmp then value = value .. Summary.DeltaText(kind, shown[key], cmp[key]) end
			lines[#lines + 1] = { label, value, cmp and Summary.FieldText(kind, cmp, key) or "" }
		end
	end
	return lines
end

local function Columns()
	return FG.view.compare and 3 or 2
end

local WRAP_SLACK, WRAP_LIMIT, MAX_WIDEN = 8, 2000, 2
local fit = { widest = {}, wrapped = {}, count = {}, size = 0 }

local function Measure()
	if not fit.measure then
		fit.measure = WINDOW_MANAGER:CreateControl(nil, win, CT_LABEL)
		fit.measure:SetFont(FONT_FACE .. "|" .. FONT_SIZE .. "|soft-shadow-thin")
		fit.measure:SetHidden(true)
	end
	return fit.measure
end

local function Remember()
	fit.size = fit.size + 1
	if fit.size > WRAP_LIMIT then fit.widest, fit.wrapped, fit.count, fit.size = {}, {}, {}, 0 end
end

local function Widest(text)
	local known = fit.widest[text]
	if known then return known end
	local most = 0
	for part in (text .. "\n"):gmatch("(.-)\n") do
		local width = Measure():GetStringWidth((part:gsub("|c%x%x%x%x%x%x", ""):gsub("|r", ""))) / GetUIGlobalScale()
		if width > most then most = width end
	end
	Remember()
	fit.widest[text] = most
	return most
end

local function Wrap(text, width)
	if text == "" then return "", 1 end
	local by_width = fit.wrapped[width]
	if not by_width then
		by_width = {}
		fit.wrapped[width], fit.count[width] = by_width, {}
	end
	local done = by_width[text]
	if done then return done, fit.count[width][text] end
	local wrapped, count = LibAPH.WrapText(Measure(), text, width)
	Remember()
	if fit.wrapped[width] then fit.wrapped[width][text], fit.count[width][text] = wrapped, count end
	return wrapped, count
end

local function Draw()
	if not built or win:IsHidden() then return false end
	local lines = Summary.Lines()
	local columns = Columns()
	local s = Saved()
	local widths = { LABEL_W, VALUE_W, VALUE_W }
	for _, line in ipairs(lines) do
		for c = 1, columns do
			local text = line[c] or ""
			if text ~= "" then
				local need = Widest(text) + 6 + WRAP_SLACK
				local base = c == 1 and LABEL_W or VALUE_W
				if need > widths[c] then widths[c] = math.min(math.ceil(need), base * MAX_WIDEN) end
			end
		end
	end
	local row_lines, total_lines = {}, 0
	for i, line in ipairs(lines) do
		local most = 1
		for c = 1, columns do
			local _, used = Wrap(line[c] or "", widths[c] - 6 - WRAP_SLACK)
			if used > most then most = used end
		end
		row_lines[i] = most
		total_lines = total_lines + most
	end
	local inner_w = widths[1] + (columns > 1 and widths[2] or 0) + (columns > 2 and widths[3] or 0)
	local inner_h = total_lines * (FONT_SIZE + 5)
	local max_w, max_h = GuiRoot:GetWidth() - SCREEN_EDGE * 2, GuiRoot:GetHeight() - SCREEN_EDGE * 2
	if s.summary_w and s.summary_h then
		local room_w = math.min(s.summary_w, max_w) - PAD * 2
		local room_h = math.min(s.summary_h, max_h) - HEADER_H - PAD
		scale = zo_clamp(math.min(room_w / inner_w, room_h / inner_h), MIN_SCALE, MAX_SCALE)
		scale = zo_clamp(math.floor(FONT_SIZE * scale + 1e-6), MIN_FONT, MAX_FONT) / FONT_SIZE
	else
		scale = 1
	end
	local font = Font()
	local row_h = (FONT_SIZE + 5) * scale
	title:SetFont(font)
	for i = #cells + 1, #lines do
		cells[i] = { Label(win, "Row" .. i .. "a"), Label(win, "Row" .. i .. "b"), Label(win, "Row" .. i .. "c") }
	end
	local above = 0
	for i, line in ipairs(lines) do
		local row = cells[i]
		local y = HEADER_H + PAD / 2 + above * row_h
		local x = PAD
		for c = 1, 3 do
			local cell = row[c]
			local cell_w = widths[c] * scale
			cell:SetFont(font)
			cell:SetMaxLineCount(row_lines[i])
			cell:ClearAnchors()
			cell:SetAnchor(TOPLEFT, win, TOPLEFT, x, y)
			cell:SetWidth(cell_w - 6)
			cell:SetText((Wrap(line[c] or "", widths[c] - 6 - WRAP_SLACK)))
			cell:SetHidden(c > columns)
			x = x + cell_w
		end
		above = above + row_lines[i]
	end
	for i = #lines + 1, #cells do
		for c = 1, 3 do cells[i][c]:SetHidden(true) end
	end
	if not resizing then
		win:SetDimensions(floor(math.min(PAD * 2 + inner_w * scale, max_w) + 0.5), floor(math.min(HEADER_H + PAD + inner_h * scale, max_h) + 0.5))
	end
	return true
end
Summary.Draw = Draw

local function PlaceDefault(control)
	control:ClearAnchors()
	control:SetAnchor(CENTER, GuiRoot, CENTER, -200, 0)
end

local function SaveSize()
	Saved().summary_w, Saved().summary_h = floor(win:GetWidth() + 0.5), floor(win:GetHeight() + 0.5)
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
	header:SetColor(TITLE_BAR[1], TITLE_BAR[2], TITLE_BAR[3], TITLE_BAR[4])
	title = Label(win, "Title")
	title:SetText("|c" .. THEME.TITLE_HEX .. "APH-FPSGraph|r  " .. FG.L("SUMMARY"))
	title:SetAnchor(LEFT, win, TOPLEFT, PAD, HEADER_H / 2)
	LibAPH.CreateThemedCloseButton(win, NAME .. "Close", function() Summary.Hide() end, 4, 2)
	for i = 1, #ROWS + 1 do
		cells[i] = { Label(win, "Row" .. i .. "a"), Label(win, "Row" .. i .. "b"), Label(win, "Row" .. i .. "c") }
	end
	win:SetHandler("OnMouseUp", function(_, button, upInside)
		if upInside and button == MOUSE_BUTTON_INDEX_RIGHT then FG.Graph.OpenMenu(win) end
	end)

	LibAPH.MakeWindowResizable(win, {
		handleSize = 8,
		minWidth = 200, minHeight = 160,
		onResizing = function()
			resizing = true
			SaveSize()
			Draw()
			if FG.Pad then FG.Pad.Refresh() end
		end,
		onResizeStop = function()
			resizing = false
			SaveSize()
			Draw()
			if FG.Pad then FG.Pad.Refresh() end
		end,
	})
	mover = LibAPH.CreateGamepadMover(win)
	position = LibAPH.CreateWindowPosition(win, {
		get = function() return Saved().summary_x, Saved().summary_y, Saved().summary_point end,
		set = function(x, y, point) Saved().summary_x, Saved().summary_y, Saved().summary_point = x, y, point end,
		placeDefault = PlaceDefault,
		mover = mover,
	})
	win:SetHandler("OnMoveStop", function() position:Save() end)
	mover:RegisterCallback(FG.name .. "_SummaryMove", 2, function()
		position:Save()
		if FG.Pad then FG.Pad.Refresh() end
	end)
	resizer = LibAPH.CreateGamepadResizer(win, {
		minWidth = 200, minHeight = 160,
		onResizing = function()
			resizing = true
			SaveSize()
			Draw()
			if FG.Pad then FG.Pad.Refresh() end
		end,
		onResizeStop = function()
			resizing = false
			SaveSize()
			Draw()
			if FG.Pad then FG.Pad.Refresh() end
		end,
	})
	sticky = LibAPH.CreateStickyFragment(win, { "hud", "hudui" })
	return win
end

function Summary.Show()
	resizing = false
	Build()
	position:Apply()
	sticky:Open()
	Draw()
	if FG.Pad then FG.Pad.Opened("summary") end
	return true
end

function Summary.Hide()
	if not built then return false end
	sticky:Close()
	if mover then mover:ToggleGamepadMove(false) end
	if resizer then resizer:ToggleGamepadResize(false) end
	if FG.Pad then FG.Pad.Refresh() end
	return true
end

function Summary.IsShown() return built and sticky:IsOpen() end

function Summary.Toggle()
	if Summary.IsShown() then return Summary.Hide() end
	return Summary.Show()
end

function Summary.Refresh()
	return Draw()
end

function Summary.OnBucket()
	if FG.view.show == nil then Draw() end
end

function Summary.Window() return win end
function Summary.Mover() return mover end
function Summary.Resizer() return resizer end

function Summary.ResetPosition()
	if not built then return false end
	position:Reset()
	return true
end
