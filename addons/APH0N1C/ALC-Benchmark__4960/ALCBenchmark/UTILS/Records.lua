--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

local AB = ALCBenchmark
local UI = AB.UI

function UI.Dur(seconds)
	seconds = math.floor(seconds + 0.5)
	if seconds < 60 then return seconds .. " s" end
	if seconds < 3600 then return string.format("%d min %d s", math.floor(seconds / 60), seconds % 60) end
	return string.format("%d h %d min %d s", math.floor(seconds / 3600), math.floor(seconds % 3600 / 60), seconds % 60)
end

function UI.TestTimeParts(record)
	local columns = record.columns or {}
	local parts = { measure = 0, load = 0, load_n = 0, reload = 0, reload_n = 0 }
	for _, c in ipairs(columns) do
		parts.measure = parts.measure + (c.seconds or 0)
		if c.load_s then parts.load, parts.load_n = parts.load + c.load_s, parts.load_n + 1 end
		if c.reload_s then parts.reload, parts.reload_n = parts.reload + c.reload_s, parts.reload_n + 1 end
	end
	local phases = math.max(#columns - 2, 0)
	local clock = record.clock
	parts.settle_each = clock and clock.settle_s or (record.isolated and 10 or nil)
	parts.settle = parts.settle_each and parts.settle_each * (phases + (record.fair_before and 1 or 0) + (record.fair_after and record.isolated and 1 or 0)) or 0
	if clock and clock.start_ts and record.end_ts then
		parts.total = record.end_ts - clock.start_ts - (clock.gap_s or 0)
		parts.gap = clock.gap_s or 0
		parts.fresh, parts.fresh_n = clock.iso_s or 0, clock.iso_n or 0
		parts.home, parts.home_n = clock.home_s or 0, clock.home_n or 0
		local rest = parts.total - parts.measure - parts.settle - parts.load - parts.reload - parts.fresh - parts.home
		parts.rest = rest >= 1 and rest or 0
		return parts
	end
	parts.fresh_n, parts.home_n = 0, 0
	if record.isolated then
		local previous_reload = false
		for index = 2, #columns - 1 do
			if not previous_reload then parts.fresh_n = parts.fresh_n + 1 end
			previous_reload = columns[index].reload_s ~= nil
		end
		if record.same_place then parts.home_n = parts.load_n end
	end
	return parts
end

function UI.FailReason(column)
	if type(column) ~= "table" then return nil end
	if column.cut_reason then return column.cut_reason end
	if column.low_memory then return "low memory" end
	if column.limit_s then return "memory limit" end
	return nil
end

function UI.FailedColumns(columns, record)
	local failed, marked = {}, false
	for _, column in ipairs(columns or {}) do
		local reason = not column.ghost and UI.FailReason(column)
		if reason then
			failed[column] = reason
			if column.cut_reason then marked = true end
		end
	end
	if record and record.recovered and not marked then
		local last
		for _, column in ipairs(columns or {}) do
			if not column.ghost and (column.frames or 0) > 0 then last = column end
		end
		if last and not failed[last] then failed[last] = "cut off" end
	end
	return failed
end

function UI.FailDetail(column, reason, record)
	local label = tostring(column.label or "?")
	if column.low_memory then
		local when = column.low_memory_late and "during its loading screen or reload" or string.format("after %d s", math.floor((column.limit_s or 0) + 0.5))
		if reason == "out of memory" then
			return string.format("%s failed %s: the game warned \"%s\", then the add-ons ran out of memory and were disabled.", label, when, column.low_memory)
		end
		if column.limit_why then
			local warned = column.low_memory:find("^Low Add%-On memory") and string.format(" (the game had warned \"%s\")", column.low_memory) or ""
			return string.format("%s failed %s: the add-on pool was at %s of %s MB and %s%s, so it was ended with a reload.", label, when, AB.Fmt(column.limit_pool or 0, 2), AB.Fmt(column.limit_cap or 0), column.limit_why, warned)
		end
		if column.limit_pool and column.limit_cap and column.limit_pool >= column.limit_cap * AB.TIMING.kill_share - 5 then
			local warned = column.low_memory:find("^Low Add%-On memory") and string.format(" after the game warned \"%s\"", column.low_memory) or ""
			return string.format("%s failed %s: the add-on pool kept growing to %s of %s MB%s without being cleaned, so it was ended with a reload.", label, when, AB.Fmt(column.limit_pool), AB.Fmt(column.limit_cap), warned)
		end
		return string.format("%s failed %s: the game warned \"%s\".", label, when, column.low_memory)
	end
	if column.limit_s then
		return string.format("%s ended after %d s at the add-on memory limit (pool %s of %s MB).", label, math.floor(column.limit_s + 0.5), AB.Fmt(column.limit_pool or 0), AB.Fmt(column.limit_cap or 0))
	end
	if record and record.recovered then return record.recovered end
	return string.format("%s: the test was cut off here (%s).", label, reason)
end

function UI.MatchColumn(columns, index, row)
	if row.after then
		for k = #columns, 1, -1 do
			if columns[k].after then return columns[k] end
		end
		return nil
	end
	local other = columns[index]
	if other and other.after then return nil end
	return other
end

function UI.AverageColumns(records)
	local out, counts = {}, {}
	for _, record in ipairs(records) do
		for index, column in ipairs(record.columns or {}) do
			local avg, count = out[index], counts[index]
			if not avg then
				avg, count = {}, {}
				out[index], counts[index] = avg, count
			end
			for key, value in pairs(column) do
				if type(value) == "number" then
					avg[key], count[key] = (count[key] and avg[key] or 0) + value, (count[key] or 0) + 1
				elseif avg[key] == nil and type(value) ~= "table" then
					avg[key] = value
				end
			end
		end
	end
	for index, avg in ipairs(out) do
		for key, count in pairs(counts[index]) do avg[key] = avg[key] / count end
	end
	return out
end

local function Near(a, b, slack) return math.abs(a - b) <= slack end

local function SeriesAgree(column, metric, list)
	local avg, peak = column[metric .. "_avg"], column[metric .. "_peak"]
	if not (list and avg and peak) then return true end
	local sum, count, top, first, last = 0, 0, nil, nil, nil
	for _, value in ipairs(list) do
		if type(value) == "number" then
			sum, count = sum + value, count + 1
			top = top and math.max(top, value) or value
			first, last = first or value, value
		end
	end
	if count == 0 then return true end
	if not Near(avg, sum / count, 0.15 + math.abs(avg) * 0.002) or not Near(peak, top, 0.15) then return false end
	local finish, start = column[metric .. "_end"], column[metric .. "_start"]
	if finish and not Near(finish, last, 5 + math.abs(last) * 0.05) then return false end
	if start and not Near(start, first, 5 + math.abs(first) * 0.05) then return false end
	return true
end

function UI.RecordConsistent(record)
	for _, column in ipairs(record.columns or {}) do
		local series = UI.Series(column)
		if series and not (SeriesAgree(column, "lua", series.lua) and SeriesAgree(column, "pool", series.pool)) then return false end
		if column.avg_fps and column.avg_ms and column.avg_ms > 0 and not Near(column.avg_fps, 1000 / column.avg_ms, 0.15 + column.avg_fps * 0.005) then return false end
		if column.frames and column.avg_fps and column.seconds and column.frames > 0
			and math.abs(column.frames - column.avg_fps * column.seconds) > column.frames * 0.03 + 5 then
			return false
		end
	end
	return true
end
