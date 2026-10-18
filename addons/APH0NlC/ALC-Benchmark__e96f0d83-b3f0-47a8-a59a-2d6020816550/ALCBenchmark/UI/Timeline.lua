--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

local AB = ALCBenchmark
local TLC, Font, view, UI, Fmt, METHOD_NAMES = AB.TLC, AB.Font, AB.view, AB.UI, AB.Fmt, AB.METHOD_NAMES
local cells, MAX_COLUMNS, HEADER_H, STATUS_H, PAD, SCROLL_H = AB.cells, AB.MAX_COLUMNS, AB.HEADER_H, AB.STATUS_H, AB.PAD, AB.SCROLL_H

AB.laid_out = {}

local tl = { pools = {}, used = {}, labels = {}, label_used = {}, slice_lua = {}, slice_pool = {}, slice_col = {}, slice_away = {}, plots = {} }

local function EventKey(event)
	if event.player or event.held then return "player" end
	if event.warning then return "warning" end
	if event.cleaner then return event.cleaner end
	if event.gc then return "gc" end
	return "cleanup"
end
tl.EventKey = EventKey

function tl.Canvas()
	if not tl.canvas then tl.canvas = LibAPH.CreateGraphCanvas(tl.area, { levels = TLC.levels, font = Font, textColor = TLC.axis_text }) end
	return tl.canvas
end

function tl.Text(kind, text, color)
	return tl.Canvas():Text(kind, text, color)
end

function tl.Measure()
	if not tl.measure then
		tl.measure = WINDOW_MANAGER:CreateControl(nil, tl.area, CT_LABEL)
		tl.measure:SetHidden(true)
	end
	tl.measure:SetFont(Font())
	return tl.measure
end

function tl.NameFont(size)
	return AB.FONT_FACE .. "|" .. size .. "|soft-shadow-thin"
end

function tl.FitName(text, width)
	local size = zo_clamp(zo_round(AB.FONT_SIZE * AB.scale), AB.MIN_FONT, AB.MAX_FONT)
	local measure = tl.Measure()
	while size >= TLC.names_min_font do
		measure:SetFont(tl.NameFont(size))
		local wrapped, used, over = LibAPH.WrapText(measure, text, width)
		if not over and used <= TLC.names_max then return wrapped, used, size end
		size = size - 1
	end
	return nil, 0, nil
end

function tl.Rect(kind, x, y, w, h, color)
	return tl.Canvas():Rect(kind, x, y, w, h, color)
end

function tl.Total()
	local total = 0
	for _, column in ipairs(view.columns) do
		local series = not column.ghost and UI.Series(column)
		if series then total = total + #series.lua end
	end
	return total
end

function tl.Locate(second)
	local before = 0
	for index, column in ipairs(view.columns) do
		local series = not column.ghost and UI.Series(column)
		if series then
			local count = #series.lua
			if second <= before + count then return index, column, second - before end
			before = before + count
		end
	end
end

function UI.TimelineMarkerAt(cursor)
	local _, column, second = tl.Locate(cursor)
	if not column then return false end
	for _, event in ipairs(column.events or {}) do
		local key = EventKey(event)
		if key and not UI.TimelineHidden(key) and math.floor(event.at) + 1 == second then return true end
	end
	for _, note in ipairs(column.notes or {}) do
		if not UI.TimelineHidden("note") and (note.at or 0) + 1 == second then return true end
	end
	local series = UI.Series(column)
	return series ~= nil and second == #series.lua and (column.lua_post_travel ~= nil or column.lua_post_reload ~= nil or tl.Failed()[column] ~= nil)
end

function tl.View(total)
	local zoom = TLC.zooms[view.tl_zoom or 1] or 1
	local span = math.max(1, math.ceil(total / zoom))
	local cursor = zo_clamp(view.tl_cursor or 1, 1, math.max(total, 1))
	local from = view.tl_from or 1
	if cursor < from then from = cursor end
	if cursor > from + span - 1 then from = cursor - span + 1 end
	from = zo_clamp(from, 1, math.max(total - span + 1, 1))
	view.tl_from, view.tl_cursor, view.tl_span = from, cursor, span
	return from, span
end

function tl.Failed()
	return UI.FailedColumns(view.columns, not view.cross and view.shown or nil)
end

function tl.Name(phase, failed)
	local reason = failed[phase]
	if reason then return tostring(phase.label or "") .. " (" .. reason .. ")", TLC.failed end
	return phase.label or "", TLC.title
end

function UI.TimelineDetail()
	local index, column, second = tl.Locate(view.tl_cursor or 1)
	if not column then return nil end
	local series = UI.Series(column)
	local reason = tl.Failed()[column]
	local text = string.format("%s, %s: Lua %s MB", column.label or "?", LibAPH.FormatClock(second - 1), Fmt(series.lua[second]))
	if series.pool[second] then text = text .. ", pool " .. Fmt(series.pool[second]) .. " MB" end
	if series.away and series.away[second] == 1 then text = text .. ", game in the background" end
	for _, event in ipairs(column.events or {}) do
		if math.floor(event.at) + 1 == second then
			if event.held then
				text = text .. ". " .. AB.Tint(event.held == "mgc" and "Memory Garbage Collector's timer came round in combat (simulated), so it skipped its check"
					or "ALC wanted to clean, but held off in combat (simulated)", TLC.player)
			elseif event.player then
				local how_long = event.length and string.format(" for %d s", event.length) or ""
				local said = { menu = "Simulated action: inventory open" .. how_long, idle = "Simulated action: idle" .. how_long,
					combat = "Simulated action: combat" .. how_long .. " (ALC and Memory Garbage Collector do not clean until it ends)" }
				text = text .. ". " .. AB.Tint(said[event.player] or tostring(event.player), TLC.player)
			elseif event.warning then
				text = text .. ". " .. AB.Tint(string.format("The game warned \"%s\"", event.warning), reason and TLC.failed or TLC.back)
				text = text .. (reason and string.format(". The phase did not survive it (%s)", reason) or ". The phase survived it")
			elseif event.alc_reload then
				text = text .. ". " .. AB.Tint(string.format("ALC reloaded the UI for low memory (pool %s MB); the phase counts and the test carried on", Fmt(event.alc_reload, 2)), TLC.cleanup)
			elseif event.cleaner then
				local name = AB.CleanerName(event.cleaner)
				if event.forced then
					text = text .. ". " .. AB.Tint(string.format("%s's own cleanup did not clean, so the benchmark cleaned in its place: freed %s MB (counted)", name, Fmt(event.freed, 2)), TLC[event.cleaner] or TLC.cleanup)
				elseif event.idle then
					local why = event.cleaner == "mgc" and "it was under its own limit" or "its cleanup freed nothing"
					text = text .. ". " .. AB.Tint(string.format("%s did not clean: %s (not counted in the conclusion)", name, why), TLC[event.cleaner] or TLC.cleanup)
				elseif event.own then
					text = text .. ". " .. AB.Tint(string.format("%s cleaned on its own timer: freed %s MB", name, Fmt(event.freed, 2)), TLC[event.cleaner] or TLC.cleanup)
				else
					text = text .. ". " .. AB.Tint(string.format("%s cleanup: freed %s MB", name, Fmt(event.freed, 2)), TLC[event.cleaner] or TLC.cleanup)
				end
			elseif event.gc then
				text = text .. string.format(". Game GC: freed %s MB", Fmt(event.freed, 2))
			elseif event.lowmem then
				local took = event.took and string.format(", took %s s%s", Fmt(event.took, 1), event.cpu and string.format(" (%d ms of CPU)", event.cpu) or "") or ""
				text = text .. ". " .. AB.Tint(string.format("ALC low-memory cleanup: %s, freed %s MB%s", event.method and METHOD_NAMES[event.method] or "?", Fmt(event.freed, 2), took), TLC.cleanup)
			elseif event.own then
				local during = ({ idle = " on its idle check", menu = " with the inventory open", after_combat = " after combat" })[event.during or ""] or ""
				text = text .. string.format(". ALC cleaned on its own%s: %s, freed %s MB", during, event.method and METHOD_NAMES[event.method] or "?", Fmt(event.freed, 2))
			else
				text = text .. string.format(". ALC cleanup: %s, freed %s MB", event.method and METHOD_NAMES[event.method] or "?", Fmt(event.freed, 2))
			end
		end
	end
	for _, note in ipairs(column.notes or {}) do
		if (note.at or 0) + 1 == second then text = text .. ". " .. AB.Tint("Note: " .. tostring(note.text), TLC.note) end
	end
	local near = math.max(1, math.ceil((view.tl_span or 1) / 60))
	if reason and second >= #series.lua - near then
		text = text .. ". " .. AB.Tint(UI.FailDetail(column, reason, not view.cross and view.shown or nil), AB.BAD)
	end
	return text, index
end

function tl.Panel(plot, caption, low, high, unit, digits, empty)
	tl.Rect("plot", plot.x, plot.y, plot.w, plot.h, TLC.inset)
	local heading = tl.Text("title", caption, TLC.title)
	LibAPH.RaiseLabel(heading, { level = TLC.levels.title, color = TLC.inset })
	heading:ClearAnchors()
	heading:SetAnchor(TOPLEFT, tl.area, TOPLEFT, plot.x + 6, plot.y + 3)
	if empty then return end
	for step = 0, TLC.grid_steps do
		local y = plot.y + plot.h - step / TLC.grid_steps * plot.h
		tl.Rect("grid", plot.x, math.min(y, plot.y + plot.h - 1), plot.w, 1, TLC.grid)
		local value = low + (high - low) * step / TLC.grid_steps
		local label = tl.Text("axis", Fmt(value, digits) .. (step == TLC.grid_steps and (" " .. unit) or ""))
		label:ClearAnchors()
		label:SetAnchor(RIGHT, tl.area, TOPLEFT, plot.x - 6, y)
	end
end

local IDLE_TICK = { TLC.player[1], TLC.player[2], TLC.player[3], 0.45 }

local LEGEND_KEYS = { "lua", "pool", "cleanup", "mgc", "shissu", "gc", "player", "travel", "away_key", "warning", "note", "failed" }
local HUE_GAP = 22

local function Hue(color)
	local r, g, b = color[1], color[2], color[3]
	local high, low = math.max(r, g, b), math.min(r, g, b)
	if high - low < 0.2 then return nil end
	local hue
	if high == r then hue = ((g - b) / (high - low)) % 6
	elseif high == g then hue = (b - r) / (high - low) + 2
	else hue = (r - g) / (high - low) + 4 end
	return hue * 60
end

local function FromHue(degrees)
	local h = degrees / 60
	local c, v = 0.62, 0.95
	local x = c * (1 - math.abs(h % 2 - 1))
	local m = v - c
	local r, g, b
	if h < 1 then r, g, b = c, x, 0 elseif h < 2 then r, g, b = x, c, 0 elseif h < 3 then r, g, b = 0, c, x
	elseif h < 4 then r, g, b = 0, x, c elseif h < 5 then r, g, b = x, 0, c else r, g, b = c, 0, x end
	return { r + m, g + m, b + m, 1 }
end

function tl.CompareColor(index, count)
	if count <= 1 then return TLC.compared end
	tl.compare_colors = tl.compare_colors or {}
	local cached = tl.compare_colors[index]
	if cached then return cached end
	local taken = {}
	for _, key in ipairs(LEGEND_KEYS) do
		local hue = TLC[key] and Hue(TLC[key])
		if hue then taken[#taken + 1] = hue end
	end
	for k = 1, index - 1 do taken[#taken + 1] = Hue(tl.CompareColor(k, count)) end
	local hue = 0
	for step = 0, 200 do
		hue = (300 + (index + step) * 137.508) % 360
		local free = true
		for _, used in ipairs(taken) do
			local gap = math.abs(hue - used) % 360
			if math.min(gap, 360 - gap) < HUE_GAP then free = false break end
		end
		if free then break end
	end
	tl.compare_colors[index] = FromHue(hue)
	return tl.compare_colors[index]
end

function tl.Compared(from, per, slices)
	tl.cmp_out = tl.cmp_out or {}
	local outs = tl.cmp_out
	for index = #view.compared + 1, #outs do outs[index] = nil end
	for index, against in ipairs(view.compared) do
		local flat = { lua = {}, pool = {} }
		local at = 0
		for _, column in ipairs(against.columns or {}) do
			local series = UI.Series(column)
			if series and series.lua then
				for second = 1, #series.lua do
					at = at + 1
					flat.lua[at] = series.lua[second] or false
					flat.pool[at] = series.pool and series.pool[second] or false
				end
			end
		end
		local out = outs[index] or { lua = {}, pool = {} }
		outs[index] = out
		for _, list in pairs(out) do for k = #list, 1, -1 do list[k] = nil end end
		for k = 1, slices do
			local first = math.floor(from + (k - 1) * per + 0.5)
			local last = math.max(first, math.floor(from + k * per - 1 + 0.5))
			local lua_sum, n, pool_sum, pool_n = 0, 0, 0, 0
			for second = first, last do
				local lua = flat.lua[second]
				if lua then lua_sum, n = lua_sum + lua, n + 1 end
				local pool = flat.pool[second]
				if pool then pool_sum, pool_n = pool_sum + pool, pool_n + 1 end
			end
			out.lua[k] = n > 0 and lua_sum / n or false
			out.pool[k] = pool_n > 0 and pool_sum / pool_n or false
		end
	end
	return #outs > 0 and outs or nil
end

function tl.HasPool()
	local function Any(columns)
		for _, column in ipairs(columns or {}) do
			local series = not column.ghost and UI.Series(column)
			for _, value in ipairs(series and series.pool or {}) do
				if value then return true end
			end
		end
		return false
	end
	if Any(view.columns) then return true end
	for _, record in ipairs(view.compared) do
		if Any(record.columns) then return true end
	end
	return false
end

UI.TIMELINE_KEYS = {
	{ "lua", "Lua" }, { "pool", "Pool" }, { "cleanup", "ALC cleanup" }, { "mgc", "MGC cleanup" }, { "shissu", "Shissu cleanup" }, { "gc", "Vanilla GC" }, { "player", "Simulated actions" }, { "travel", "Loading screen or reload" },
	{ "away", "Game in background" }, { "warning", "Low memory warning" }, { "note", "Note" },
	{ "failed", "Failed or cut off" }, { "compared", "Compared tests" },
}

function UI.TimelineHidden(key)
	local hidden = AB.saved and AB.saved.tl_hidden
	return hidden ~= nil and hidden[key] == true
end

function UI.ToggleTimelineKey(key)
	AB.saved.tl_hidden = AB.saved.tl_hidden or {}
	AB.saved.tl_hidden[key] = not AB.saved.tl_hidden[key] or nil
	if next(AB.saved.tl_hidden) == nil then AB.saved.tl_hidden = nil end
	if view.page == "timeline" and UI.IsShown() then UI.Draw() end
	return not UI.TimelineHidden(key)
end

local legend_keys = setmetatable({}, { __mode = "k" })

local function LegendClick(label, button, upInside)
	if upInside and button == MOUSE_BUTTON_INDEX_LEFT and legend_keys[label] then UI.ToggleTimelineKey(legend_keys[label]) end
end

function tl.Legend(x, y, right, present)
	local start, rows = x, 1
	local entries = {}
	local function Add(key, name, color, group) entries[#entries + 1] = { key = key, name = name, color = color, group = group } end
	Add("lua", "Lua", TLC.lua)
	if present.pool then Add("pool", "Pool", TLC.pool) end
	if present.cleanup then Add("cleanup", "ALC cleanup", TLC.cleanup) end
	for _, cleaner in ipairs(AB.CLEANERS) do
		if present[cleaner.key] then Add(cleaner.key, cleaner.short .. " cleanup", TLC[cleaner.key]) end
	end
	if present.gc then Add("gc", "Vanilla GC", TLC.gc) end
	if present.player then Add("player", "Simulated actions", TLC.player) end
	if present.travel then Add("travel", "Loading screen or reload", TLC.travel) end
	if present.away then Add("away", "Game in background", TLC.away_key) end
	if present.warning_ok then Add("warning", "Low memory warning, survived", TLC.back) end
	if present.warning_bad then Add("warning", "Low memory warning, failed", TLC.failed) end
	if present.warning and not (present.warning_ok or present.warning_bad) then Add("warning", "Low memory warning", TLC.warning) end
	if present.note then Add("note", "Note", TLC.note) end
	if present.failed then Add("failed", "Failed or cut off", TLC.failed) end
	local compared_count = view.cross and 0 or #view.compared
	if compared_count == 1 then
		Add("compared", "Compared test", TLC.compared)
	else
		for index = 1, compared_count do
			Add("compared" .. index, "Compared: " .. UI.TestName(view.compared[index]), tl.CompareColor(index, compared_count), "compared")
		end
	end
	for _, entry in ipairs(entries) do
		local hidden = UI.TimelineHidden(entry.key) or (entry.group ~= nil and UI.TimelineHidden(entry.group))
		local alpha = hidden and TLC.hidden_alpha or 1
		local label = tl.Text("legend", entry.name, { TLC.title[1], TLC.title[2], TLC.title[3], alpha })
		if not legend_keys[label] then
			label:SetMouseEnabled(true)
			label:SetHandler("OnMouseUp", LegendClick)
		end
		legend_keys[label] = entry.key
		local width = label:GetTextWidth()
		local item_w = TLC.legend_sample + 4 + (type(width) == "number" and width or 60)
		if x > start and x + item_w > right then
			x, y, rows = start, y + TLC.legend_h, rows + 1
		end
		tl.Rect("legend", x, y + 4, TLC.legend_sample, 8, { entry.color[1], entry.color[2], entry.color[3], alpha })
		label:ClearAnchors()
		label:SetAnchor(LEFT, tl.area, TOPLEFT, x + TLC.legend_sample + 4, y + 8)
		x = x + item_w + 14
	end
	return rows * TLC.legend_h
end

local function DrawTimeline(w, h)
	for i = 1, #cells do
		for c = 1, MAX_COLUMNS do cells[i][c]:SetHidden(true) end
	end
	AB.laid_out = {}
	AB.notes:SetHidden(true)
	tl.area:SetHidden(false)
	local total = tl.Total()
	local from, span
	local status_text
	if total == 0 then
		status_text = view.status ~= "" and view.status or "No timeline yet: it fills in while a test measures."
	else
		from, span = tl.View(total)
		status_text = UI.TimelineDetail() or view.status or ""
	end
	local wrapped_status, status_rows = LibAPH.WrapText(tl.Measure(), status_text, math.max(w - PAD * 2 - 8, 40))
	view.status_rows = status_rows
	AB.status:SetMaxLineCount(status_rows)
	AB.status:SetText(wrapped_status)
	local top = HEADER_H + STATUS_H + (status_rows - 1) * (AB.FONT_SIZE + 5) + PAD
	local area_w, area_h = math.max(w - PAD * 2, 1), math.max(h - top - PAD - SCROLL_H, 1)
	tl.area:ClearAnchors()
	tl.area:SetAnchor(TOPLEFT, AB.win, TOPLEFT, PAD, top)
	tl.area:SetDimensions(area_w, area_h)
	tl.Canvas():Begin()
	if total == 0 then
		tl.Canvas():Finish()
		AB.scroller:SetHidden(true)
		return
	end
	local plot_x = TLC.axis_w
	local plot_w = area_w - plot_x - 4
	local has_pool = tl.HasPool()
	local failed = tl.Failed()
	local present = { pool = has_pool, failed = next(failed) ~= nil }
	for _, column in ipairs(view.columns) do
		if not column.ghost then
			for _, event in ipairs(column.events or {}) do
				local key = EventKey(event)
				if key then present[key] = true end
				if event.warning then present[failed[column] and "warning_bad" or "warning_ok"] = true end
			end
			if column.notes and #column.notes > 0 then present.note = true end
			if column.lua_post_travel or column.lua_post_reload then present.travel = true end
			if (column.away_s or 0) > 0 then present.away = true end
		end
	end
	tl.legend_used = tl.Legend(plot_x, 0, area_w, present)
	local lanes, lane_of = {}, {}
	for _, lane in ipairs({ { "cleanup", "ALC", { "cleanup" } }, { "mgc", "MGC", { "mgc" } }, { "shissu", "Shissu", { "shissu" } }, { "gc", "Vanilla GC", { "gc" } }, { "player", "Simulated", { "player" } }, { "warning", "Low memory", { "warning" } }, { "note", "Notes", { "note" } } }) do
		for _, key in ipairs(lane[3]) do
			if present[key] and not UI.TimelineHidden(key) and not lane_of[lane[1]] then
				lanes[#lanes + 1] = lane
				lane_of[lane[1]] = #lanes
			end
		end
	end
	tl.plot_x, tl.plot_w = plot_x, plot_w

	local slices = math.max(1, math.min(span, math.floor(plot_w / TLC.slice_px), TLC.max_slices))
	local per = span / slices
	for index = slices + 1, #tl.slice_lua do tl.slice_lua[index], tl.slice_pool[index], tl.slice_col[index] = nil, nil, nil end
	local column_index, column, second_in = tl.Locate(from)
	local lua_min, lua_max, pool_min, pool_max = math.huge, -math.huge, math.huge, -math.huge
	for k = 1, slices do
		local first = math.floor(from + (k - 1) * per + 0.5)
		local last = math.max(first, math.floor(from + k * per - 1 + 0.5))
		local lua_sum, pool_sum, n, pool_n, away = 0, 0, 0, 0, false
		tl.slice_col[k] = column_index
		for _ = first, last do
			if not column then break end
			local series = UI.Series(column)
			lua_sum, n = lua_sum + series.lua[second_in], n + 1
			local pool = series.pool[second_in]
			if pool then pool_sum, pool_n = pool_sum + pool, pool_n + 1 end
			if series.away and series.away[second_in] == 1 then away = true end
			second_in = second_in + 1
			if second_in > #series.lua then
				repeat
					column_index = column_index + 1
					column = view.columns[column_index]
				until not column or (not column.ghost and UI.Series(column) and #UI.Series(column).lua > 0)
				second_in = 1
			end
		end
		local lua = n > 0 and lua_sum / n or nil
		local pool = pool_n > 0 and pool_sum / pool_n or nil
		tl.slice_lua[k], tl.slice_pool[k], tl.slice_away[k] = lua or false, pool or false, away
		if lua then lua_min, lua_max = math.min(lua_min, lua), math.max(lua_max, lua) end
		if pool then pool_min, pool_max = math.min(pool_min, pool), math.max(pool_max, pool) end
	end

	local cmp = #view.compared > 0 and not view.cross and tl.Compared(from, per, slices)
	for _, out in ipairs(cmp or {}) do
		for k = 1, slices do
			local lua, pool = out.lua[k], out.pool[k]
			if lua then lua_min, lua_max = math.min(lua_min, lua), math.max(lua_max, lua) end
			if pool then pool_min, pool_max = math.min(pool_min, pool), math.max(pool_max, pool) end
		end
	end

	local function Range(low, high)
		if low == math.huge then return 0, 1 end
		local step = math.max(LibAPH.NiceGraphStep((high - low) / TLC.grid_steps), 0.5)
		low = math.floor(low / step) * step
		high = math.max(math.ceil(high / step) * step, low + step * TLC.grid_steps)
		return low, high
	end
	local lua_low, lua_high = Range(lua_min, lua_max)
	local pool_low, pool_high = Range(pool_min, pool_max)

	local bar_w = plot_w / slices
	local names_lines = 1
	do
		local col, start_slot = nil, 1
		local function Need(to_slot)
			local width = (to_slot - start_slot + 1) * bar_w
			local phase = col and view.columns[col]
			if phase and width >= 40 then
				local _, used = tl.FitName((tl.Name(phase, failed)), width - 4)
				if used > names_lines then names_lines = used end
			end
		end
		for k = 1, slices do
			if tl.slice_col[k] ~= col then
				if col then Need(k - 1) end
				col, start_slot = tl.slice_col[k], k
			end
		end
		if col then Need(slices) end
	end
	local lanes_y = tl.legend_used + names_lines * TLC.names_h + 8
	local first_y = lanes_y + #lanes * TLC.lane_h + (#lanes > 0 and 6 or 0)
	local usable = area_h - first_y - TLC.ticks_h - TLC.gap_h * 2
	usable = math.max(usable + TLC.gap_h, TLC.gap_h * 3)
	local lua_plot = { x = plot_x, w = plot_w, y = first_y, h = has_pool and math.floor(usable * 0.6) or usable }
	local pool_plot = has_pool and { x = plot_x, w = plot_w, y = lua_plot.y + lua_plot.h + TLC.gap_h, h = usable - lua_plot.h - TLC.gap_h } or nil
	local plots = pool_plot and { lua_plot, pool_plot } or { lua_plot }
	local bottom_plot = pool_plot or lua_plot
	local phase_number, previous_col, band_from = 0, nil, 1
	local function Band(to_slot)
		if not previous_col then return end
		local x = plot_x + (band_from - 1) * bar_w
		local width = (to_slot - band_from + 1) * bar_w
		if phase_number % 2 == 0 then
			for _, plot in ipairs(plots) do tl.Rect("band", x, plot.y, width, plot.h, TLC.band) end
		end
		local phase = view.columns[previous_col]
		local wrapped, used, size, color
		if phase and width >= 40 then
			local text
			text, color = tl.Name(phase, failed)
			wrapped, used, size = tl.FitName(text, width - 4)
		end
		if wrapped then
			local name = tl.Text("names", wrapped, color)
			name:SetFont(tl.NameFont(size))
			name:SetMaxLineCount(used)
			name:SetWidth(width - 4)
			name:ClearAnchors()
			name:SetAnchor(TOPLEFT, tl.area, TOPLEFT, x + 2, tl.legend_used + 2)
		end
		if band_from > 1 then
			tl.Rect("sep", x, lua_plot.y, 1, bottom_plot.y + bottom_plot.h - lua_plot.y, TLC.sep)
		end
	end
	for k = 1, slices do
		if tl.slice_col[k] ~= previous_col then
			Band(k - 1)
			phase_number = phase_number + 1
			previous_col, band_from = tl.slice_col[k], k
		end
	end
	Band(slices)

	tl.Panel(lua_plot, "Lua memory", lua_low, lua_high, "MB", (lua_high - lua_low) < 10 and 1 or 0)
	if pool_plot then tl.Panel(pool_plot, "Add-on pool", pool_low, pool_high, "MB", (pool_high - pool_low) < 10 and 1 or 0) end
	if not UI.TimelineHidden("away") then
		for k = 1, slices do
			if tl.slice_away[k] then tl.Rect("away", lua_plot.x + (k - 1) * bar_w, lua_plot.y, bar_w, lua_plot.h, TLC.away) end
		end
	end
	for index, lane in ipairs(lanes) do
		local y = lanes_y + (index - 1) * TLC.lane_h
		tl.Rect("lane", plot_x, y + 1, plot_w, TLC.lane_h - 2, TLC.lane_bg)
		local label = tl.Text("lanes", lane[2], TLC.axis_text)
		label:SetFont(tl.NameFont(TLC.lane_h - 3))
		label:ClearAnchors()
		label:SetAnchor(RIGHT, tl.area, TOPLEFT, plot_x - 6, y + TLC.lane_h / 2)
	end

	if not UI.TimelineHidden("compared") then
		for index, out in ipairs(cmp or {}) do
			if not UI.TimelineHidden("compared" .. index) and not (#cmp == 1 and UI.TimelineHidden("compared")) then
				local color = tl.CompareColor(index, #cmp)
				local function Compared() return color end
				tl.Canvas():Line(lua_plot, out.lua, lua_low, lua_high, Compared, TLC.line_t)
				if pool_plot then tl.Canvas():Line(pool_plot, out.pool, pool_low, pool_high, Compared, TLC.line_t) end
			end
		end
	end
	if not UI.TimelineHidden("lua") then tl.Canvas():Line(lua_plot, tl.slice_lua, lua_low, lua_high, function() return TLC.lua end, TLC.line_t) end
	if pool_plot and not UI.TimelineHidden("pool") then tl.Canvas():Line(pool_plot, tl.slice_pool, pool_low, pool_high, function() return TLC.pool end, TLC.line_t) end

	local start = 0
	for _, phase in ipairs(view.columns) do
		local phase_series = not phase.ghost and UI.Series(phase)
		if phase_series then
			local function Shown(second) return second >= from and second <= from + span - 1 end
			local function X(second) return plot_x + (second - from + 0.5) / span * plot_w end
			local function Line(second, color)
				if Shown(second) then tl.Rect("mark", X(second) - 1, lua_plot.y, 2, bottom_plot.y + bottom_plot.h - lua_plot.y, color) end
			end
			local function Tick(lane_key, second, color, wide, half)
				local lane = lane_of[lane_key]
				if not lane or not Shown(second) then return end
				local y, tick_h = lanes_y + (lane - 1) * TLC.lane_h + 2, TLC.lane_h - 4
				if half then y, tick_h = y + tick_h / 2, tick_h / 2 end
				tl.Rect("mark", X(second) - (wide and 2 or 1), y, wide and 4 or 2, tick_h, color)
			end
			for _, event in ipairs(phase.events or {}) do
				local key = EventKey(event)
				if key and not UI.TimelineHidden(key) then
					local second = start + math.floor(event.at) + 1
					if key == "warning" then Tick("warning", second, failed[phase] and TLC.failed or TLC.back)
					elseif key == "gc" then Tick("gc", second, TLC.gc)
					elseif key == "player" and event.held then Tick("player", second, event.held == "mgc" and TLC.mgc or TLC.cleanup, true)
					elseif key == "player" then Tick("player", second, event.player == "idle" and IDLE_TICK or TLC.player, false, event.player == "combat")
					elseif AB.CLEANER_BY_KEY[key] then Tick(key, second, TLC[key], false, event.idle)
					else Tick("cleanup", second, TLC.cleanup, event.lowmem or event.alc_reload ~= nil) end
				end
			end
			if not UI.TimelineHidden("note") then
				for _, note in ipairs(phase.notes or {}) do Tick("note", start + (note.at or 0) + 1, TLC.note) end
			end
			local finish = start + #phase_series.lua
			if not UI.TimelineHidden("travel") then
				if phase.lua_post_travel then Line(finish, TLC.travel) end
				if phase.lua_post_reload then Line(finish, TLC.reload) end
			end
			if failed[phase] and not UI.TimelineHidden("failed") then Line(finish, TLC.failed) end
			start = finish
		end
	end

	local step = LibAPH.GraphTickStep(span, TLC.target_ticks, TLC.tick_steps)
	local t = math.ceil((from - 1) / step) * step
	while t <= from - 1 + span do
		local x = plot_x + (t - (from - 1)) / span * plot_w
		tl.Rect("tick", x, bottom_plot.y + bottom_plot.h, 1, 4, TLC.axis_text)
		local label = tl.Text("ticks", LibAPH.FormatClock(t))
		label:ClearAnchors()
		label:SetAnchor(TOP, tl.area, TOPLEFT, x, bottom_plot.y + bottom_plot.h + 5)
		t = t + step
	end

	local cursor_x = plot_x + (view.tl_cursor - from + 0.5) / span * plot_w
	tl.Rect("cursor", cursor_x, lua_plot.y, 1, bottom_plot.y + bottom_plot.h - lua_plot.y, TLC.cursor)
	tl.Canvas():Finish()

	local can_pan = span < total
	AB.scroller:SetHidden(not can_pan)
	if can_pan then
		AB.scroller:SetMinMax(1, total - span + 1)
		AB.scroller:SetValue(from)
	end
end
AB.tl, AB.DrawTimeline = tl, DrawTimeline
