--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

local APHP = APHProfilerCore

local last_report
local SUBCALLS_KEPT = 3

local function ByOwnTime(a, b)
	if a.own == b.own then return a.owner < b.owner end
	return a.own > b.own
end

local function ByFunctionTime(a, b)
	if a.own == b.own then return a.label < b.label end
	return a.own > b.own
end

function APHP.SeverityColor(ms)
	if ms >= 500 then return "FF0000" end
	if ms >= 100 then return "FFA500" end
	if ms >= 20 then return "FFFF00" end
	if ms >= 5 then return "00FF00" end
	if ms >= 1 then return "FFFFFF" end
	return "888888"
end

function APHP.BuildReport(owners, funcs, frames, elapsed_ms)
	frames = frames or 0
	elapsed_ms = elapsed_ms or 0

	local rows, measured = {}, 0
	if type(owners) == "table" then
		for _, row in pairs(owners) do
			rows[#rows + 1] = row
			measured = measured + row.own
		end
	end
	table.sort(rows, ByOwnTime)

	local by_owner = {}
	for _, row in ipairs(rows) do
		row.funcs = {}
		by_owner[row.owner] = row
	end
	if type(funcs) == "table" then
		for _, entry in pairs(funcs) do
			local owner_row = by_owner[entry.owner]
			if owner_row then owner_row.funcs[#owner_row.funcs + 1] = entry end
		end
	end

	local detail_limit = APHP.LimitFor("funcs", APHP.saved.detail_rows)
	if type(detail_limit) ~= "number" or detail_limit < 1 then detail_limit = 20 end
	for _, row in ipairs(rows) do
		table.sort(row.funcs, ByFunctionTime)
		for index = #row.funcs, detail_limit + 1, -1 do row.funcs[index] = nil end
		for _, entry in ipairs(row.funcs) do
			local subs = {}
			for child_key, wall in pairs(entry.children or {}) do
				local child = funcs[child_key]
				if child then subs[#subs + 1] = { label = child.label, wall = wall } end
			end
			table.sort(subs, function(a, b) return a.wall > b.wall end)
			for index = #subs, SUBCALLS_KEPT + 1, -1 do subs[index] = nil end
			entry.subcalls = subs
		end
	end
	if type(funcs) == "table" then
		for _, entry in pairs(funcs) do entry.children = nil end
	end

	local previous = APHP.GetPreviousRun()
	local before = {}
	if previous and (previous.frames or 0) > 0 then
		for _, entry in ipairs(APHP.GetRunRows(previous)) do
			before[entry.o] = entry.m / previous.frames
		end
	end
	for _, row in ipairs(rows) do
		row.per_frame = frames > 0 and row.own / frames or 0
		local was = before[row.owner]
		if was then row.delta = row.per_frame - was end
	end

	last_report = {
		rows = rows,
		frames = frames,
		elapsed_ms = elapsed_ms,
		measured_ms = measured,
		at = GetTimeStamp(),
		compared_to = previous and previous.at or nil,
	}
	return last_report
end

function APHP.GetLastReport() return last_report end

function APHP.GetListLimit()
	local limit = APHP.saved and APHP.saved.report_rows
	if type(limit) ~= "number" or limit < 1 then return 15 end
	return limit
end
function APHP.ClearLastReport() last_report = nil end

function APHP.FormatPercent(delta, before)
	if not before or before <= 0 then return "" end
	return string.format(" %+.0f%%", delta / before * 100)
end

function APHP.FormatDelta(delta, before)
	if not delta then return "" end
	if delta >= 0 then
		return string.format("  |cFF6666+%s/frame%s|r", APHP.Format(delta), APHP.FormatPercent(delta, before))
	end
	return string.format("  |c66FF66-%s/frame%s|r", APHP.Format(-delta), APHP.FormatPercent(delta, before))
end

function APHP.ShowLastReport()
	return APHP.ShowHud()
end

function APHP.BuildExportText()
	local report = last_report
	if not report then return nil end

	local out = {}
	out[#out + 1] = string.format("APH-Profiler %s", APHP.VERSION)
	out[#out + 1] = string.format("Recorded %s", report.at and GetDateStringFromTimestamp(report.at) or "?")
	out[#out + 1] = string.format("%d frames over %.1f s, add-on Lua %.2f ms",
		report.frames, report.elapsed_ms / 1000, report.measured_ms)
	out[#out + 1] = ""

	for index, row in ipairs(report.rows) do
		out[#out + 1] = string.format("%d. %s  own %.2f ms  total %.2f ms  %.4f ms/frame  peak %.2f ms  %d calls",
			index, LibAPH.StripColors(row.owner), row.own, row.total, row.per_frame or 0, row.peak, row.calls)
		for _, entry in ipairs(row.funcs or {}) do
			out[#out + 1] = string.format("      %.2f ms  %d calls  %s", entry.own, entry.calls, entry.label)
		end
	end
	return table.concat(out, "\n")
end
