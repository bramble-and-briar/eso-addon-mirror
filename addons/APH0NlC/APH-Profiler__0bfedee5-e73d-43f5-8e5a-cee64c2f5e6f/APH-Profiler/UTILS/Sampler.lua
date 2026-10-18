--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

local APHP = APHProfilerCore

local PARSE_JOB = "APHProfiler_Parse"
local NS_PER_MS = 1000000
local MAX_CALLER_HOPS = 64
local TIMELINE_BUCKETS = 600
local CONSOLE_TIMELINE_BUCKETS = 120
local MIN_TIMELINE_OWNERS = 15
APHP.TIMELINE_OTHER = "Other"
local MAX_STACK = 6
local WORST_FRAMES_KEPT = 3
local FUNCS_KEPT_SHARE = 3
local MIN_FUNCS_KEPT = 30
local TRIM_SHARE = 2
local TRIM_HARD_SHARE = 4

local ESOUI_OWNER = APHP.L("GAME_UI")
local GC_OWNER = APHP.L("LUA_GARBAGE_COLLECTOR")

local state = {
	running = false,
	parsing = false,
	frame = 0,
	frames = 0,
	started_at = 0,
	elapsed_ms = 0,
	owners = nil,
	funcs = nil,
	timeline = nil,
}

local path_owner = {}
local addon_roots = {}
local library_names = {}

local duration = {}
local caller = {}
local child_time = {}
local owner_of = {}
local data_index = {}
local data_type = {}
local func_key = {}

function APHP.IsRunning() return state.running end

function APHP.GetRecordingElapsedMs()
	if not state.running then return nil end
	return GetGameTimeMilliseconds() - state.started_at
end
function APHP.IsParsing() return state.parsing end

function APHP.AdoptRecording(started_at, kind)
	if state.running or state.parsing then return false end
	state.running = true
	state.started_at = started_at or GetGameTimeMilliseconds()
	state.kind = kind
	APHP.StartScanWatch()
	if APHP.OnRecordingStarted then APHP.OnRecordingStarted() end
	return true
end

local function BuildAddonIndex()
	addon_roots = {}
	library_names = {}
	path_owner = {}

	local am = GetAddOnManager()
	if not am then return end
	for index = 1, am:GetNumAddOns() do
		local name, _, _, _, _, _, _, is_library = am:GetAddOnInfo(index)
		local root = am:GetAddOnRootDirectoryPath(index)
		if name and root and root ~= "" then
			addon_roots[#addon_roots + 1] = { prefix = string.upper(root), name = name }
			if is_library then library_names[name] = true end
		end
	end
end

local function OwnerForPath(path)
	if not path or path == "" then return nil end
	local cached = path_owner[path]
	if cached ~= nil then return cached or nil end

	local upper = string.upper(path)
	local owner
	for index = 1, #addon_roots do
		local entry = addon_roots[index]
		if string.find(upper, entry.prefix, 1, true) then
			owner = entry.name
			break
		end
	end
	if not owner and string.find(upper, "ESOUI", 1, true) then owner = ESOUI_OWNER end

	path_owner[path] = owner or false
	return owner
end

local function DirectOwner(dataIndex, dataType)
	if dataType == SCRIPT_PROFILER_RECORD_DATA_TYPE_CLOSURE then
		local _, path = GetScriptProfilerClosureInfo(dataIndex)
		return OwnerForPath(path)
	end
	if dataType == SCRIPT_PROFILER_RECORD_DATA_TYPE_GARBAGE_COLLECTION then
		return GC_OWNER
	end
	return nil
end

local function OwnerAbove(recordIndex, count)
	local index = caller[recordIndex]
	local hops = 0
	while index and index >= 1 and index <= count and hops < MAX_CALLER_HOPS do
		local owner = owner_of[index]
		if owner then return owner end
		index = caller[index]
		hops = hops + 1
	end
	return nil
end

local function IsExcluded(owner)
	if owner == APHP.name and APHP.saved.exclude_self then return true end
	if APHP.saved.exclude_libraries and library_names[owner] then return true end
	return false
end

local function BaseName(path)
	if not path then return "?" end
	return string.match(path, "([^/\\]+)$") or path
end

local function LabelFor(dataIndex, dataType)
	if dataType == SCRIPT_PROFILER_RECORD_DATA_TYPE_CLOSURE then
		local name, path, line = GetScriptProfilerClosureInfo(dataIndex)
		if name and name ~= "" then
			return string.format("%s  %s:%d", name, BaseName(path), line or 0)
		end
		return string.format("%s:%d", BaseName(path), line or 0)
	end
	if dataType == SCRIPT_PROFILER_RECORD_DATA_TYPE_CFUNCTION then
		return (GetScriptProfilerCFunctionInfo(dataIndex) or "?") .. "()"
	end
	if dataType == SCRIPT_PROFILER_RECORD_DATA_TYPE_GARBAGE_COLLECTION then
		return APHP.L("GARBAGE_COLLECTION")
	end
	if dataType == SCRIPT_PROFILER_RECORD_DATA_TYPE_USER_EVENT then
		return APHP.L("EVENT") .. (GetScriptProfilerUserEventInfo(dataIndex) or "?")
	end
	return "?"
end

local function StackFor(index, count)
	local stack, at = {}, index
	while at and at >= 1 and at <= count and #stack < MAX_STACK do
		if data_index[at] then stack[#stack + 1] = LabelFor(data_index[at], data_type[at]) end
		at = caller[at]
	end
	return stack
end

local function CreditFunction(owner, index, count, own_ms)
	local dataIndex, dataType = data_index[index], data_type[index]
	local key = owner .. "\t" .. tostring(dataType) .. ":" .. tostring(dataIndex)
	local wall = duration[index]
	local row = state.funcs[key]
	if not row then
		row = { owner = owner, label = LabelFor(dataIndex, dataType), own = 0, calls = 0, wall = 0,
			min = wall, max = -1, children = {} }
		state.funcs[key] = row
		local keys = state.owner_keys[owner]
		if not keys then
			keys = {}
			state.owner_keys[owner] = keys
		end
		keys[key] = true
		local held = (state.func_counts[owner] or 0) + 1
		state.func_counts[owner] = held
		if held > state.funcs_kept * TRIM_HARD_SHARE then state.trim_due = true end
	end
	row.own = row.own + own_ms
	row.calls = row.calls + 1
	row.wall = row.wall + wall
	if wall < row.min then row.min = wall end
	if wall > row.max then
		row.max = wall
		row.stack = StackFor(index, count)
	end
	return key
end

local function ByOwn(a, b)
	if a.own == b.own then return a.key < b.key end
	return a.own > b.own
end

local function TrimFunctions(share)
	local keep = state.funcs_kept
	for owner, held in pairs(state.func_counts) do
		if held > keep * share then
			local keys, list = state.owner_keys[owner], {}
			for key in pairs(keys) do
				local row = state.funcs[key]
				if row then list[#list + 1] = { key = key, own = row.own } end
			end
			table.sort(list, ByOwn)
			for index = keep + 1, #list do
				state.funcs[list[index].key] = nil
				keys[list[index].key] = nil
			end
			state.func_counts[owner] = math.min(#list, keep)
		end
	end
	state.trim_due = false
end

local function FunctionsKept()
	local limit = APHP.LimitFor("funcs", APHP.saved.detail_rows)
	if type(limit) ~= "number" or limit < 1 then limit = 20 end
	return math.max(limit * FUNCS_KEPT_SHARE, MIN_FUNCS_KEPT)
end

local function NewTimeline(frames)
	local cap = IsConsoleUI() and CONSOLE_TIMELINE_BUCKETS or TIMELINE_BUCKETS
	local buckets = frames < cap and frames or cap
	local timeline = { buckets = buckets, frames = frames, frames_in = {}, owners = {}, worst_in = {}, worst = {}, worst_without = { {}, {}, {} } }
	for bucket = 1, buckets do
		timeline.frames_in[bucket] = 0
		timeline.worst_in[bucket] = 0
	end
	return timeline
end

local function BucketFor(frameIndex)
	local timeline = state.timeline
	return math.floor((frameIndex - 1) * timeline.buckets / timeline.frames) + 1
end

local function ByFrameMs(a, b) return a.ms > b.ms end

local function KeepWorst(list, frameIndex, total, owner, owner_ms)
	if total <= 0 or (#list >= WORST_FRAMES_KEPT and total <= list[#list].ms) then return end
	list[#list + 1] = { frame = frameIndex, ms = total, owner = owner, owner_ms = owner_ms }
	table.sort(list, ByFrameMs)
	if #list > WORST_FRAMES_KEPT then list[#list] = nil end
end

local function LeftOut(owner, mask)
	return (mask % 2 == 1 and owner == ESOUI_OWNER) or (mask >= 2 and owner == GC_OWNER)
end

local function NoteFrame(frameIndex, frame_owner_ms)
	local timeline = state.timeline
	if not timeline then return end
	local bucket = BucketFor(frameIndex)
	timeline.frames_in[bucket] = timeline.frames_in[bucket] + 1

	local frame_total, top_owner, top_ms = 0, nil, 0
	local second_owner, second_ms, third_owner, third_ms = nil, 0, nil, 0
	for owner, ms in pairs(frame_owner_ms) do
		local series = timeline.owners[owner]
		if not series then
			series = {}
			timeline.owners[owner] = series
		end
		series[bucket] = (series[bucket] or 0) + ms
		frame_total = frame_total + ms
		if ms > top_ms then
			third_owner, third_ms, second_owner, second_ms, top_owner, top_ms = second_owner, second_ms, top_owner, top_ms, owner, ms
		elseif ms > second_ms then
			third_owner, third_ms, second_owner, second_ms = second_owner, second_ms, owner, ms
		elseif ms > third_ms then
			third_owner, third_ms = owner, ms
		end
	end
	if frame_total > timeline.worst_in[bucket] then timeline.worst_in[bucket] = frame_total end

	KeepWorst(timeline.worst, frameIndex, frame_total, top_owner, top_ms)
	local game_ms, gc_ms = frame_owner_ms[ESOUI_OWNER] or 0, frame_owner_ms[GC_OWNER] or 0
	for mask = 1, 3 do
		local total = frame_total - (mask % 2 == 1 and game_ms or 0) - (mask >= 2 and gc_ms or 0)
		local owner, owner_ms = top_owner, top_ms
		if LeftOut(owner, mask) then owner, owner_ms = second_owner, second_ms end
		if LeftOut(owner, mask) then owner, owner_ms = third_owner, third_ms end
		if owner then KeepWorst(timeline.worst_without[mask], frameIndex, total, owner, owner_ms) end
	end
end

function APHP.TrimTimeline(timeline, rows)
	if not timeline then return nil end
	local keep = {}
	local limit = math.max(APHP.GetListLimit(), MIN_TIMELINE_OWNERS)
	for index = 1, math.min(#rows, limit) do keep[rows[index].owner] = true end
	local other = {}
	for owner, series in pairs(timeline.owners) do
		if not keep[owner] then
			for bucket, ms in pairs(series) do other[bucket] = (other[bucket] or 0) + ms end
			timeline.owners[owner] = nil
		end
	end
	if next(other) then timeline.owners[APHP.TIMELINE_OTHER] = other end
	return timeline
end

local function Credit(owner, own_ms, total_ms)
	local row = state.owners[owner]
	if not row then
		row = { owner = owner, own = 0, total = 0, calls = 0, peak = 0 }
		state.owners[owner] = row
	end
	row.own = row.own + own_ms
	row.total = row.total + total_ms
	row.calls = row.calls + 1
	if own_ms > row.peak then row.peak = own_ms end
end

local RECORD_CHUNK = 128
local READ_GC_SHARE = 0.75
local READ_STOP_SHARE = 0.9
local READ_GC_KB = 64
local RECORD_ARRAYS = 7
local BYTES_PER_SLOT = 16
local GROWTH_HEADROOM = 2
local BYTES_PER_MB = 1048576
local READ_BUDGET_MIN_MS = IsConsoleUI() and 2 or 3
local READ_BUDGET_MAX_MS = IsConsoleUI() and 10 or 12
local READ_BUDGET_STEP_MS = 1
local READ_SLOW_SHARE = 0.1
local READ_SLACK_MS = 1
local READ_HITCH_SHARE = 1.5
local READ_SMOOTHING = 0.25
local READ_BASELINE_FRAMES = 10
local READ_REBASE_FRAMES = 30
local step_started, step_budget, chunk_work = 0, 0, 0
local tune = { budget = nil, base = nil, sum = 0, samples = 0, smooth = 0, frame_at = nil, stuck = 0 }

local function ResetReadBudget()
	if tune.budget and LibAPH.SetSchedulerBudgetMs then LibAPH.SetSchedulerBudgetMs(nil) end
	tune.budget, tune.base, tune.sum, tune.samples, tune.smooth, tune.frame_at, tune.stuck = nil, nil, 0, 0, 0, nil, 0
end

local function TuneReadBudget()
	if not (LibAPH.SetSchedulerBudgetMs and GetFrameDeltaTimeMilliseconds) then return end
	local frame_at = GetFrameTimeMilliseconds and GetFrameTimeMilliseconds()
	if frame_at ~= nil and frame_at == tune.frame_at then return end
	tune.frame_at = frame_at
	local delta = GetFrameDeltaTimeMilliseconds()
	if type(delta) ~= "number" or delta <= 0 then return end
	if not tune.base then
		tune.sum, tune.samples = tune.sum + delta, tune.samples + 1
		if tune.samples >= READ_BASELINE_FRAMES then
			tune.base = tune.sum / tune.samples
			tune.smooth = tune.base
			tune.budget = READ_BUDGET_MIN_MS
		end
		return
	end
	tune.smooth = tune.smooth + (delta - tune.smooth) * READ_SMOOTHING
	if delta >= tune.base * READ_HITCH_SHARE then
		tune.budget = math.max(READ_BUDGET_MIN_MS, math.floor(tune.budget / 2))
		tune.stuck = 0
	elseif tune.smooth > tune.base * (1 + READ_SLOW_SHARE) + READ_SLACK_MS then
		if tune.budget > READ_BUDGET_MIN_MS then
			tune.budget = tune.budget - READ_BUDGET_STEP_MS
			tune.stuck = 0
		else
			tune.stuck = tune.stuck + 1
			if tune.stuck >= READ_REBASE_FRAMES then
				tune.base, tune.stuck = tune.smooth, 0
			end
		end
	else
		tune.budget = math.min(tune.budget + READ_BUDGET_STEP_MS, READ_BUDGET_MAX_MS)
		tune.stuck = 0
	end
	LibAPH.SetSchedulerBudgetMs(tune.budget)
end

function APHP.GetReadBudgetMs()
	return tune.budget
end
local array_slots = 0

local function TimeLeft()
	if LibAPH.StepTimeLeftMs then return LibAPH.StepTimeLeftMs() end
	return step_budget - (GetGameTimeSeconds() * 1000 - step_started)
end

local function OutOfTime()
	return TimeLeft() <= 0
end

local function PoolUse()
	if not (LibAPH.GetAddOnMemoryLimitMB and IsConsoleUI()) then return nil end
	local used, cap = LibAPH.GetAddOnMemoryLimitMB()
	if type(used) ~= "number" or type(cap) ~= "number" or cap <= 0 then return nil end
	local stop = math.min(cap * READ_STOP_SHARE, APHP.ConsoleMemoryStopMB and APHP.ConsoleMemoryStopMB() or cap)
	return used / stop * READ_STOP_SHARE, used, stop
end

local function PoolStop()
	if state.pool_stop then return true end
	local share, used, stop = PoolUse()
	if share and share >= READ_STOP_SHARE then
		state.pool_stop = { used = used, cap = math.floor(stop + 0.5) }
		return true
	end
	return false
end

local function SlotsFor(count)
	local slots = 1
	while slots < count do slots = slots * 2 end
	return slots
end

local function FrameFits(count)
	if count <= array_slots then return true end
	local share, used, stop = PoolUse()
	if not share then return true end
	local slots = SlotsFor(count)
	local need_mb = RECORD_ARRAYS * slots * BYTES_PER_SLOT * GROWTH_HEADROOM / BYTES_PER_MB
	return used + need_mb < stop
end

local function ReadRecords(frameIndex, first, last)
	for index = first, last do
		local dataIndex, startNS, endNS, callerIndex, dataType = GetScriptProfilerRecordInfo(frameIndex, index)
		local ms = 0
		if startNS and endNS and endNS > startNS then ms = (endNS - startNS) / NS_PER_MS end
		duration[index] = ms
		caller[index] = callerIndex
		child_time[index] = 0
		data_index[index] = dataIndex
		data_type[index] = dataType
		owner_of[index] = dataIndex and DirectOwner(dataIndex, dataType) or false
	end
end

local function SumChildren(first, last, count)
	for index = first, last do
		local parent = caller[index]
		if parent and parent >= 1 and parent <= count then
			child_time[parent] = child_time[parent] + duration[index]
		end
	end
end

local function CreditRecords(first, last, count, frame_owner_ms)
	for index = first, last do
		func_key[index] = false
		local owner = owner_of[index] or OwnerAbove(index, count)
		if owner and not IsExcluded(owner) then
			local own = duration[index] - child_time[index]
			if own < 0 then own = 0 end
			Credit(owner, own, duration[index])
			frame_owner_ms[owner] = (frame_owner_ms[owner] or 0) + own
			if data_index[index] then func_key[index] = CreditFunction(owner, index, count, own) end
		end
	end
end

local function LinkChildren(first, last, count)
	for index = first, last do
		local parent = caller[index]
		local parent_key = parent and parent >= 1 and parent <= count and func_key[parent]
		local parent_row = parent_key and func_key[index] and state.funcs[parent_key]
		if parent_row then
			local children = parent_row.children
			children[func_key[index]] = (children[func_key[index]] or 0) + duration[index]
		end
	end
end

local function ParseSome()
	local frame = state.partial
	if not frame then
		state.frame = state.frame + 1
		local count = GetScriptProfilerFrameNumRecords(state.frame) or 0
		if count < 1 then
			NoteFrame(state.frame, {})
			return true
		end
		if not FrameFits(count) then
			state.skipped = state.skipped + 1
			NoteFrame(state.frame, {})
			return true
		end
		if count > array_slots then array_slots = SlotsFor(count) end
		frame = { count = count, phase = 1, index = 1, owner_ms = {} }
		state.partial = frame
	end
	local count = frame.count
	while frame.phase <= 4 do
		local first = frame.index
		local last = math.min(first + RECORD_CHUNK - 1, count)
		if frame.phase == 1 then
			ReadRecords(state.frame, first, last)
		elseif frame.phase == 2 then
			SumChildren(first, last, count)
		elseif frame.phase == 3 then
			CreditRecords(first, last, count, frame.owner_ms)
		else
			LinkChildren(first, last, count)
		end
		if last >= count then
			frame.phase, frame.index = frame.phase + 1, 1
		else
			frame.index = last + 1
		end
		if state.trim_due and frame.phase ~= 4 then TrimFunctions(1) end
		chunk_work = chunk_work + last - first + 1
		if chunk_work >= RECORD_CHUNK and frame.phase <= 4 then
			chunk_work = 0
			if PoolStop() then return false end
			if OutOfTime() then return false end
		end
	end
	state.partial = nil
	NoteFrame(state.frame, frame.owner_ms)
	TrimFunctions(TRIM_SHARE)
	return true
end

local function ReleaseBuffers()
	duration = {}
	caller = {}
	child_time = {}
	owner_of = {}
	data_index = {}
	data_type = {}
	func_key = {}
	path_owner = {}
	array_slots = 0
end

local function CutTimeline(timeline, read)
	if not timeline or read >= timeline.frames then return end
	local last = math.max(BucketFor(math.max(read, 1)), 1)
	for bucket = last + 1, timeline.buckets do
		timeline.frames_in[bucket], timeline.worst_in[bucket] = nil, nil
		for _, series in pairs(timeline.owners) do series[bucket] = nil end
	end
	timeline.buckets, timeline.frames = last, read
end

local function ElapsedFor(frames)
	if state.frames > 0 and frames < state.frames then return state.elapsed_ms * frames / state.frames end
	return state.elapsed_ms
end

local function FinishParse(cut)
	state.parsing = false
	ResetReadBudget()
	local frames, elapsed = state.frames, state.elapsed_ms
	if cut then
		frames = math.max(state.frame, 1)
		elapsed = ElapsedFor(frames)
		CutTimeline(state.timeline, frames)
	end
	state.partial = nil
	state.pool_stop = nil
	ReleaseBuffers()
	local report = APHP.BuildReport(state.owners, state.funcs, frames, elapsed)
	if cut then report.recorded_frames = state.frames end
	if state.skipped > 0 then report.skipped_frames = state.skipped end
	if state.kind == "ui_load" then report.ui_load = true end
	report.timeline = APHP.TrimTimeline(state.timeline, report.rows)
	state.owners = nil
	state.funcs = nil
	state.owner_keys = nil
	state.func_counts = nil
	state.timeline = nil
	APHP.RecordRun(report)
	if APHP.saved.log_to_debuglogger then APHP.LogReportLines(report) end
	if cut then
		APHP.Print(string.format(APHP.L("READ_CUT_FOR_MEMORY"), frames, state.frames, cut.used, cut.cap), true)
	end
	if state.skipped > 0 then
		APHP.Print(string.format(APHP.L("FRAMES_TOO_LARGE_LEFT_OUT"), state.skipped), true)
	end
	APHP.CleanUpAfterScan()
	APHP.SetScanStatus("")
	APHP.ReturnAfterScan(APHP.saved.open_window_after_scan)
end

local function CollectSome()
	local keep = TimeLeft() / 2
	repeat
		if collectgarbage("step", READ_GC_KB) then return end
	until TimeLeft() <= keep
end

local function ReadingStatus(freeing)
	APHP.SetScanStatus(string.format(APHP.L(freeing and "READING_OF_FRAMES_FREEING" or "READING_OF_FRAMES"), state.frame, state.frames))
end

local function ParseStep()
	TuneReadBudget()
	local cap = APHP.LimitFor("frames", APHP.saved.frames_per_tick)
	if type(cap) ~= "number" or cap < 1 then cap = 1 end
	step_budget = LibAPH.GetSchedulerBudgetMs()
	step_started = GetGameTimeSeconds() * 1000
	chunk_work = 0

	local share = PoolUse()
	local freeing = share and share >= READ_GC_SHARE
	if PoolStop() then
		FinishParse(state.pool_stop)
		return true
	end
	if freeing then CollectSome() end

	local parsed = 0
	while (state.partial or state.frame < state.frames) and parsed < cap do
		if not ParseSome() then break end
		parsed = parsed + 1
		if OutOfTime() then break end
	end

	if state.pool_stop then
		FinishParse(state.pool_stop)
		return true
	end
	if not state.partial and state.frame >= state.frames then
		FinishParse()
		return true
	end
	ReadingStatus(freeing)
	return false
end

function APHP.Start()
	if state.running then
		APHP.Print(APHP.L("ALREADY_RECORDING_USE_APHPSTOP_ONCE_YOU"), true)
		return false
	end
	if state.parsing then
		APHP.Print(APHP.L("STILL_READING_THE_LAST_RECORDING_GIVE"), true)
		return false
	end
	if type(StartScriptProfiler) ~= "function" then
		APHP.Print(APHP.L("THIS_CLIENT_HAS_NO_SCRIPT_PROFILER"), true)
		return false
	end

	if APHP.ScansLoadTimes() then return APHP.StartLoadTimesScan() end
	if APHP.ProfilesUiLoad() then return APHP.StartUiLoadScan() end

	state.running = true
	state.started_at = GetGameTimeMilliseconds()
	state.kind = nil
	StartScriptProfiler()
	APHP.StartScanWatch()
	if APHP.OnRecordingStarted then APHP.OnRecordingStarted() end
	if APHP.IsTimedScan() then
		APHP.Print(string.format(APHP.L("RECORDING_FOR_DO_THE_THING_THAT"), APHP.FormatClock(APHP.ScanSeconds())))
	else
		APHP.Print(APHP.L("RECORDING_DO_THE_THING_THAT_STUTTERS"))
	end
	return true
end

function APHP.Stop()
	if not state.running then
		APHP.Print(APHP.L("NOT_RECORDING_USE_APHP_TO_START"), true)
		return false
	end

	StopScriptProfiler()
	APHP.StopScanWatch()
	state.running = false
	if APHP.OnRecordingStopped then APHP.OnRecordingStopped() end
	state.elapsed_ms = GetGameTimeMilliseconds() - state.started_at
	state.frames = GetScriptProfilerNumFrames() or 0
	if state.frames < 1 then
		APHP.Print(APHP.L("THE_RECORDING_HELD_NO_FRAMES"), true)
		APHP.ReturnAfterScan(false)
		return false
	end

	BuildAddonIndex()
	state.frame = 0
	state.partial = nil
	state.owners = {}
	state.funcs = {}
	state.owner_keys = {}
	state.func_counts = {}
	state.funcs_kept = FunctionsKept()
	state.trim_due = false
	state.skipped = 0
	state.pool_stop = nil
	state.timeline = NewTimeline(state.frames)
	state.parsing = true
	ResetReadBudget()
	APHP.SetScanStatus(string.format(APHP.L("READING_0_OF_FRAMES"), state.frames))
	APHP.StepAsideForScan(true)
	LibAPH.Schedule(PARSE_JOB, ParseStep, { oncePerFrame = true })
	return true
end

APHP.ESOUI_OWNER = ESOUI_OWNER
APHP.GC_OWNER = GC_OWNER
