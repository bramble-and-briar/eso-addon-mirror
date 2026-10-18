--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

local APHP = APHProfilerCore

local DEFAULT_MAX_RUNS = 10
local MIN_MAX_RUNS = 2
local MAX_MAX_RUNS = 50
local DEFAULT_ROWS_PER_RUN = 200
local MIN_ROWS_PER_RUN = 1
local MAX_ROWS_PER_RUN = 500

local SAVED_STAT_OWNERS = 15
local SAVED_FUNC_OWNERS = 15
local SAVED_FUNCS = 3
local MAX_SAVED_SERIES = 15
local SAVED_BUCKETS = 60
local SAVED_LABEL_MAX = 80
local CHUNK_CHARS = 1500
local SESSION_KEEP_PC = 3
local SESSION_KEEP_CONSOLE = 1
local US_PER_MS = 1000

local name_slot = {}
local session_detail = setmetatable({}, { __mode = "k" })
local session_order = {}

local function MaxRuns()
	local value = APHP.saved.max_saved_runs
	if type(value) ~= "number" then return DEFAULT_MAX_RUNS end
	if value < MIN_MAX_RUNS then return MIN_MAX_RUNS end
	if value > MAX_MAX_RUNS then return MAX_MAX_RUNS end
	return APHP.LimitFor("runs", value)
end

local function RowsPerRun()
	local value = APHP.saved.max_rows_per_run
	if type(value) ~= "number" then return DEFAULT_ROWS_PER_RUN end
	if value < MIN_ROWS_PER_RUN then return MIN_ROWS_PER_RUN end
	if value > MAX_ROWS_PER_RUN then return MAX_ROWS_PER_RUN end
	return APHP.LimitFor("rows", value)
end

local function Names()
	APHP.saved.names = APHP.saved.names or {}
	return APHP.saved.names
end

local function SlotFor(name)
	local names = Names()
	if not name_slot[name] then
		for index = 1, #names do name_slot[names[index]] = index end
	end
	local slot = name_slot[name]
	if slot then return slot end

	names[#names + 1] = name
	slot = #names
	name_slot[name] = slot
	return slot
end

local function Pieces(value)
	if type(value) == "table" then return value end
	if type(value) == "string" then return { value } end
	return {}
end

local function Chunked(parts, separator)
	local chunks, current, length = {}, {}, 0
	for _, part in ipairs(parts) do
		if length > 0 and length + #part + 1 > CHUNK_CHARS then
			chunks[#chunks + 1] = table.concat(current, separator)
			current, length = {}, 0
		end
		current[#current + 1] = part
		length = length + #part + 1
	end
	if #current > 0 then chunks[#chunks + 1] = table.concat(current, separator) end
	if #chunks == 1 then return chunks[1] end
	if #chunks == 0 then return "" end
	return chunks
end

local PACKED = "#"

local function Ints(value)
	local pieces = Pieces(value)
	if pieces[1] and string.sub(pieces[1], 1, 1) == PACKED then
		if not LibAPH.UnpackNumbers then return {} end
		local text = string.sub(table.concat(pieces), 2)
		local out = LibAPH.UnpackNumbers(text, 1)
		for index = 1, #out do out[index] = out[index] or 0 end
		return out
	end
	local out = {}
	for _, text in ipairs(pieces) do
		for token in string.gmatch(text, "[^,]+") do out[#out + 1] = tonumber(token) or 0 end
	end
	return out
end

local function Join(list)
	if LibAPH.PackNumbers then
		local packed = LibAPH.PackNumbers(list, 1)
		if type(packed) == "string" then return PACKED .. packed end
		packed[1] = PACKED .. packed[1]
		return packed
	end
	local parts = {}
	for index = 1, #list do parts[index] = string.format("%d", list[index]) end
	return Chunked(parts, ",")
end

local function SeriesText(slot, values)
	local packed = Join(values)
	if type(packed) == "table" then
		local parts = {}
		for index = 1, #values do parts[index] = string.format("%d", values[index]) end
		return slot .. "|" .. table.concat(parts, ",")
	end
	return slot .. "|" .. packed
end

local function Records(value, fields)
	local out = {}
	for _, text in ipairs(Pieces(value)) do
		for record in string.gmatch(text, "[^;]+") do
			local values, index = {}, 0
			for token in string.gmatch(record, "[^:]+") do
				index = index + 1
				values[fields[index]] = tonumber(token) or 0
			end
			out[#out + 1] = values
		end
	end
	return out
end

local function JoinRecords(list, fields)
	local parts = {}
	for index, record in ipairs(list) do
		local values = {}
		for f, field in ipairs(fields) do values[f] = string.format("%d", record[field] or 0) end
		parts[index] = table.concat(values, ":")
	end
	return Chunked(parts, ";")
end

local WORST_FIELDS = { "frame", "us", "slot", "owner_us" }
local WORST_KEYS = { "w", "w1", "w2", "w3" }
local FUNC_FIELDS = { "owner", "label", "us", "calls", "wall", "min", "max" }

local function SeriesEntries(run)
	local out = {}
	for _, text in ipairs(Pieces(run.ts)) do
		local slot, values = string.match(text, "^(%d+)|(.*)$")
		if slot then out[#out + 1] = { slot = tonumber(slot), values = Ints(values) } end
	end
	return out
end

local function RemapList(value, remap)
	local list = Ints(value)
	for index, slot in ipairs(list) do list[index] = slot > 0 and (remap[slot] or 0) or 0 end
	return Join(list)
end

local function RemapRun(run, remap)
	run.i = RemapList(run.i, remap)
	if run.td then run.td = RemapList(run.td, remap) end
	for _, key in ipairs(WORST_KEYS) do
		if run[key] then
			local worst = Records(run[key], WORST_FIELDS)
			for _, record in ipairs(worst) do record.slot = remap[record.slot] or 0 end
			run[key] = JoinRecords(worst, WORST_FIELDS)
		end
	end
	if run.f then
		local funcs = Records(run.f, FUNC_FIELDS)
		for _, record in ipairs(funcs) do
			record.owner = remap[record.owner] or 0
			record.label = remap[record.label] or 0
		end
		run.f = JoinRecords(funcs, FUNC_FIELDS)
	end
	if run.ts then
		local series = {}
		for _, entry in ipairs(SeriesEntries(run)) do
			series[#series + 1] = SeriesText(remap[entry.slot] or 0, entry.values)
		end
		run.ts = series
	end
end

local function UsedSlots(run, used)
	for _, slot in ipairs(Ints(run.i)) do used[slot] = true end
	for _, slot in ipairs(Ints(run.td)) do if slot > 0 then used[slot] = true end end
	for _, key in ipairs(WORST_KEYS) do
		for _, record in ipairs(Records(run[key], WORST_FIELDS)) do used[record.slot] = true end
	end
	for _, record in ipairs(Records(run.f, FUNC_FIELDS)) do
		used[record.owner] = true
		used[record.label] = true
	end
	for _, entry in ipairs(SeriesEntries(run)) do used[entry.slot] = true end
end

local function DropUnusedNames()
	local names = Names()
	local used = {}
	for _, run in ipairs(APHP.GetRuns()) do UsedSlots(run, used) end

	local kept, remap = {}, {}
	for slot = 1, #names do
		if used[slot] then
			kept[#kept + 1] = names[slot]
			remap[slot] = #kept
		end
	end
	for _, run in ipairs(APHP.GetRuns()) do RemapRun(run, remap) end

	APHP.saved.names = kept
	name_slot = {}
	for index = 1, #kept do name_slot[kept[index]] = index end
end

local function Us(ms) return math.floor((ms or 0) * US_PER_MS + 0.5) end

local function EncodeTimeline(run, timeline)
	if type(timeline) ~= "table" or (timeline.buckets or 0) < 1 then return end
	local fine = timeline.buckets
	local count = math.min(fine, SAVED_BUCKETS)
	local other = APHP.TIMELINE_OTHER
	local avg, peak, dom, dom_avg, frames_at, owner_sums = {}, {}, {}, {}, {}, {}
	for slot = 1, count do
		local first = math.floor((slot - 1) * fine / count) + 1
		local last = math.floor(slot * fine / count)
		local frames, total, worst, by_owner = 0, 0, 0, {}
		for bucket = first, last do
			frames = frames + (timeline.frames_in[bucket] or 0)
			if (timeline.worst_in[bucket] or 0) > worst then worst = timeline.worst_in[bucket] end
			for owner, series in pairs(timeline.owners) do
				local ms = series[bucket]
				if ms then
					total = total + ms
					by_owner[owner] = (by_owner[owner] or 0) + ms
				end
			end
		end
		local lead, lead_ms = nil, 0
		for owner, ms in pairs(by_owner) do
			if owner ~= other and (ms > lead_ms or (ms == lead_ms and lead and owner < lead)) then lead, lead_ms = owner, ms end
			owner_sums[owner] = owner_sums[owner] or {}
			owner_sums[owner][slot] = ms
		end
		frames_at[slot] = frames
		avg[slot] = frames > 0 and Us(total / frames) or 0
		peak[slot] = Us(worst)
		dom[slot] = lead and SlotFor(lead) or 0
		dom_avg[slot] = (lead and frames > 0) and Us(lead_ms / frames) or 0
	end
	run.tb = count
	run.ta, run.tp, run.td, run.tm = Join(avg), Join(peak), Join(dom), Join(dom_avg)

	local ranked = {}
	for owner, sums in pairs(owner_sums) do
		if owner ~= other then
			local sum = 0
			for _, ms in pairs(sums) do sum = sum + ms end
			ranked[#ranked + 1] = { owner = owner, sum = sum }
		end
	end
	table.sort(ranked, function(a, b)
		if a.sum == b.sum then return a.owner < b.owner end
		return a.sum > b.sum
	end)
	local series = {}
	for index = 1, math.min(#ranked, APHP.GetListLimit(), MAX_SAVED_SERIES) do
		local owner, values = ranked[index].owner, {}
		for slot = 1, count do
			values[slot] = frames_at[slot] > 0 and Us((owner_sums[owner][slot] or 0) / frames_at[slot]) or 0
		end
		series[#series + 1] = SeriesText(SlotFor(owner), values)
	end
	run.ts = series

	local function EncodeWorst(list)
		local worst = {}
		for index, spike in ipairs(list or {}) do
			worst[index] = { frame = spike.frame, us = Us(spike.ms),
				slot = spike.owner and SlotFor(spike.owner) or 0, owner_us = Us(spike.owner_ms) }
		end
		return JoinRecords(worst, WORST_FIELDS)
	end
	run.w = EncodeWorst(timeline.worst)
	if type(timeline.worst_without) == "table" then
		for mask = 1, 3 do run["w" .. mask] = EncodeWorst(timeline.worst_without[mask]) end
	end
end

local function EncodeFunctions(run, report)
	local funcs = {}
	for index = 1, math.min(#report.rows, SAVED_FUNC_OWNERS) do
		local row = report.rows[index]
		for f = 1, math.min(#(row.funcs or {}), SAVED_FUNCS) do
			local entry = row.funcs[f]
			funcs[#funcs + 1] = { owner = SlotFor(row.owner), label = SlotFor(string.sub(entry.label, 1, SAVED_LABEL_MAX)),
				us = Us(entry.own), calls = entry.calls, wall = Us(entry.wall), min = Us(entry.min), max = Us(entry.max) }
		end
	end
	run.f = JoinRecords(funcs, FUNC_FIELDS)
end

local function EncodeOwners(run, report)
	local slots, times, calls, peaks, walls = {}, {}, {}, {}, {}
	local last = math.min(#report.rows, RowsPerRun())
	for index = 1, last do
		local row = report.rows[index]
		slots[index] = SlotFor(row.owner)
		times[index] = Us(row.own)
		if index <= SAVED_STAT_OWNERS then
			calls[index] = row.calls or 0
			peaks[index] = Us(row.peak)
			walls[index] = Us(row.total)
		end
	end
	run.i, run.m = Join(slots), Join(times)
	run.c, run.p, run.x = Join(calls), Join(peaks), Join(walls)
end

function APHP.GetRuns()
	APHP.saved.runs = APHP.saved.runs or {}
	return APHP.saved.runs
end

function APHP.GetPreviousRun()
	local runs = APHP.GetRuns()
	return runs[#runs]
end

function APHP.GetRunRows(run)
	if type(run) ~= "table" then return {} end
	local names = Names()
	local slots, times = Ints(run.i), Ints(run.m)
	local rows = {}
	for index, slot in ipairs(slots) do
		local name = names[slot]
		if name then rows[#rows + 1] = { o = name, m = (times[index] or 0) / US_PER_MS } end
	end
	return rows
end

local function KeepSessionDetail(run, report)
	session_detail[run] = report
	session_order[#session_order + 1] = run
	local keep = IsConsoleUI() and SESSION_KEEP_CONSOLE or SESSION_KEEP_PC
	while #session_order > keep do
		session_detail[table.remove(session_order, 1)] = nil
	end
end

local function NewRun(report)
	local run = {
		at = GetTimeStamp(),
		frames = report.frames,
		elapsed_ms = report.elapsed_ms,
		rd = report.recorded_frames,
		sk = report.skipped_frames,
		ul = report.ui_load and 1 or nil,
	}
	EncodeOwners(run, report)
	EncodeTimeline(run, report.timeline)
	EncodeFunctions(run, report)
	return run
end

function APHP.RecordRun(report)
	if type(report) ~= "table" then return false end
	local runs = APHP.GetRuns()
	local run = NewRun(report)
	runs[#runs + 1] = run
	KeepSessionDetail(run, report)
	while #runs > MaxRuns() do table.remove(runs, 1) end
	DropUnusedNames()
	return true
end

function APHP.TrimRuns()
	local runs = APHP.GetRuns()
	if #runs <= MaxRuns() then return false end
	while #runs > MaxRuns() do table.remove(runs, 1) end
	DropUnusedNames()
	return true
end

function APHP.WipeLastRun()
	local runs = APHP.GetRuns()
	if #runs == 0 then return false end
	table.remove(runs)
	DropUnusedNames()
	return true
end

function APHP.RenameRun(run, text)
	if type(run) ~= "table" then return false end
	text = zo_strtrim(text or "")
	run.name = text ~= "" and text or nil
	if APHP.RefreshHud then APHP.RefreshHud() end
	return true
end

function APHP.DeleteRun(run)
	local runs = APHP.GetRuns()
	for index = #runs, 1, -1 do
		if runs[index] == run then
			table.remove(runs, index)
			session_detail[run] = nil
			for at = #session_order, 1, -1 do
				if session_order[at] == run then table.remove(session_order, at) end
			end
			DropUnusedNames()
			return true
		end
	end
	return false
end

function APHP.WipeAllRuns()
	local runs = APHP.GetRuns()
	local removed = #runs
	for index = removed, 1, -1 do runs[index] = nil end
	APHP.saved.names = {}
	name_slot = {}
	session_order = {}
	APHP.ClearLastReport()
	return removed
end

function APHP.HasSessionDetail(run)
	return session_detail[run] ~= nil
end

local function DecodedDetail(run)
	local names = Names()
	local frames = run.frames or 0
	local calls, peaks, walls = Ints(run.c), Ints(run.p), Ints(run.x)
	local rows, by_owner, measured = {}, {}, 0
	for index, entry in ipairs(APHP.GetRunRows(run)) do
		local row = { owner = entry.o, own = entry.m, per_frame = frames > 0 and entry.m / frames or 0, funcs = {} }
		if calls[index] then
			row.calls = calls[index]
			row.peak = (peaks[index] or 0) / US_PER_MS
			row.total = (walls[index] or 0) / US_PER_MS
		end
		rows[#rows + 1] = row
		by_owner[row.owner] = row
		measured = measured + entry.m
	end
	for _, record in ipairs(Records(run.f, FUNC_FIELDS)) do
		local row = by_owner[names[record.owner]]
		if row and names[record.label] then
			row.funcs[#row.funcs + 1] = { label = names[record.label], own = record.us / US_PER_MS, calls = record.calls,
				wall = record.wall and record.wall / US_PER_MS, min = record.min and record.min / US_PER_MS,
				max = record.max and record.max / US_PER_MS, saved = true }
		end
	end

	local detail = { rows = rows, frames = frames, elapsed_ms = run.elapsed_ms or 0, measured_ms = measured, session = false }
	if run.tb and run.ta then
		local avg, peak, dom, dom_avg = Ints(run.ta), Ints(run.tp), Ints(run.td), Ints(run.tm)
		local compact = { buckets = run.tb, avg = {}, peak = {}, dominant = {}, dominant_avg = {}, worst = {}, series = {} }
		for bucket = 1, run.tb do
			compact.avg[bucket] = (avg[bucket] or 0) / US_PER_MS
			compact.peak[bucket] = (peak[bucket] or 0) / US_PER_MS
			compact.dominant[bucket] = names[dom[bucket] or 0]
			compact.dominant_avg[bucket] = (dom_avg[bucket] or 0) / US_PER_MS
		end
		for _, entry in ipairs(SeriesEntries(run)) do
			local owner = names[entry.slot]
			if owner then
				local values = {}
				for bucket = 1, run.tb do values[bucket] = (entry.values[bucket] or 0) / US_PER_MS end
				compact.series[owner] = values
			end
		end
		local function DecodeWorst(text)
			local list = {}
			for index, record in ipairs(Records(text, WORST_FIELDS)) do
				list[index] = { frame = record.frame, ms = record.us / US_PER_MS,
					owner = names[record.slot], owner_ms = record.owner_us / US_PER_MS }
			end
			return list
		end
		compact.worst = DecodeWorst(run.w)
		if run.w1 then compact.worst_without = { DecodeWorst(run.w1), DecodeWorst(run.w2), DecodeWorst(run.w3) } end
		detail.compact = compact
	end
	return detail
end

function APHP.GetRunDetail(run)
	if run == nil then
		local report = APHP.GetLastReport()
		if not report then return nil end
		report.session = true
		return report
	end
	local report = session_detail[run]
	if report then
		report.session = true
		return report
	end
	return DecodedDetail(run)
end

function APHP.DescribeRun(run)
	if type(run) ~= "table" then return "" end
	local when = run.name or (run.at and GetDateStringFromTimestamp(run.at) or "?")
	local text = string.format("%s  %d frames  %s", when, run.frames or 0, APHP.Format(run.elapsed_ms or 0))
	if run.rd then text = text .. "  " .. string.format(APHP.L("READ_OF_RECORDED_FRAMES"), run.frames or 0, run.rd) end
	if run.sk then text = text .. "  " .. string.format(APHP.L("FRAMES_LEFT_OUT"), run.sk) end
	if run.ul then text = text .. "  " .. APHP.L("UI_LOAD_TAG") end
	return text
end

function APHP.GetStoredNameCount()
	return #Names()
end

APHP.GetMaxRuns = MaxRuns
APHP.MIN_MAX_RUNS = MIN_MAX_RUNS
APHP.MAX_MAX_RUNS = MAX_MAX_RUNS
APHP.GetRowsPerRun = RowsPerRun
APHP.MIN_ROWS_PER_RUN = MIN_ROWS_PER_RUN
APHP.MAX_ROWS_PER_RUN = MAX_ROWS_PER_RUN
APHP.DEFAULT_ROWS_PER_RUN = DEFAULT_ROWS_PER_RUN
