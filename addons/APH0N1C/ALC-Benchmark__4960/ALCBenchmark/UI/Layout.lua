--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

local AB = ALCBenchmark
local UI = AB.UI

local WIN = "ALCBenchmarkWindow"
local HEADER_H = 28
local STATUS_H = 22
local PAD = 10
local FONT_SIZE = 14
local MIN_FONT, MAX_FONT = 10, 30
local LABEL_W = 190
local VALUE_W = 118
local MIN_SCALE, MAX_SCALE = 0.75, 2.2
local FONT_FACE = IsConsoleUI() and "$(GAMEPAD_MEDIUM_FONT)" or "$(BOLD_FONT)"
local TITLE_BAR = { 0, 0, 0, 0.92 }
local SCROLL_H = 22
local FIT = { min_w = 240, min_h = 200, max_data = 40, max_widen = 2 }
local PAGES = { "results", "summary", "timeline", "loading" }
local PAGE_NAMES = { results = "Results", summary = "Summary", timeline = "Timeline", loading = "Loading Screens" }
local TLC = {
	slice_px = 3, max_slices = 300, axis_w = 58, w = 1000, h = 520,
	zooms = { 1, 2, 4, 8, 16, 32 },
	grid_steps = 4, line_t = 2,
	legend_h = 18, names_h = 18, names_max = 3, names_min_font = 9, gap_h = 20, ticks_h = 22, legend_sample = 16,
	lane_h = IsConsoleUI() and 20 or 15, lane_bg = { 1, 1, 1, 0.035 }, hidden_alpha = 0.3,
	tick_steps = { 1, 2, 5, 10, 15, 30, 60, 120, 300, 600, 900, 1800 }, target_ticks = 8,
	levels = { plot = 1, band = 2, away = 2, lane = 2, grid = 3, sep = 3, tick = 3, line = 5, legend = 5, mark = 6, cursor = 7, text = 9, title = 11 },
	inset = { 0.04, 0.04, 0.06, 0.85 }, band = { 1, 1, 1, 0.04 }, grid = { 1, 1, 1, 0.08 }, sep = { 1, 1, 1, 0.22 },
	axis_text = { 0.62, 0.62, 0.66, 1 }, title = { 0.85, 0.85, 0.88, 1 }, cursor = { 1, 1, 1, 0.45 },
	lua = { 0.35, 0.68, 1, 1 }, pool = { 1, 0.5, 0.05, 1 },
	cleanup = { 0.78, 0.5, 1, 1 }, gc = { 0.95, 0.95, 0.95, 1 }, travel = { 0.62, 0.62, 0.66, 0.9 }, reload = { 0.62, 0.62, 0.66, 0.9 }, warning = { 1, 0.72, 0.15, 1 },
	mgc = { 0.25, 0.85, 0.75, 1 }, shissu = { 1, 0.4, 0.7, 1 }, player = { 0.85, 0.72, 0.5, 1 },
	away = { 0.7, 0.7, 0.7, 0.16 }, away_key = { 0.55, 0.55, 0.55, 1 }, compared = { 0.92, 0.92, 0.92, 0.75 }, failed = { 1, 0.25, 0.25, 1 }, back = { 0.35, 0.85, 0.45, 1 }, note = { 0.55, 0.8, 1, 1 },
}
local HEADER_LINES = 3
local SCREEN_EDGE = 20

local tabs = {}
local Pad = { focus = false, dismissed = false }
local cells = {}
local view = { columns = {}, compare = {}, status = "", compared = {} }

function UI.ConsoleView()
	local record = view.shown
	if type(record) == "table" and record.platform then return tostring(record.platform):find("^console") ~= nil end
	return IsConsoleUI()
end

function UI.On(key)
	return AB.saved ~= nil and AB.saved[key] ~= false
end

function UI.TestName(record)
	return record and (record.name or record.when) or "?"
end
AB.WIN, AB.HEADER_H, AB.STATUS_H, AB.PAD, AB.FONT_SIZE, AB.MIN_FONT = WIN, HEADER_H, STATUS_H, PAD, FONT_SIZE, MIN_FONT
AB.MAX_FONT, AB.LABEL_W, AB.VALUE_W, AB.MIN_SCALE, AB.MAX_SCALE, AB.FONT_FACE = MAX_FONT, LABEL_W, VALUE_W, MIN_SCALE, MAX_SCALE, FONT_FACE
AB.TITLE_BAR, AB.SCROLL_H, AB.FIT, AB.PAGES, AB.PAGE_NAMES, AB.TLC = TITLE_BAR, SCROLL_H, FIT, PAGES, PAGE_NAMES, TLC
AB.HEADER_LINES, AB.SCREEN_EDGE, AB.tabs, AB.Pad, AB.cells, AB.view = HEADER_LINES, SCREEN_EDGE, tabs, Pad, cells, view
