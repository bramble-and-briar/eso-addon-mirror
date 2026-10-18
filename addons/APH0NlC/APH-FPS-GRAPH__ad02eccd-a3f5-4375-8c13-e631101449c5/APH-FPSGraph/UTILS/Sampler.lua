--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

local FG = APHFPSGraphCore
local S = {}
FG.Sampler = S

local floor, sqrt, ceil, min, max = math.floor, math.sqrt, math.ceil, math.min, math.max
local GetFrameDeltaSeconds = GetFrameDeltaSeconds

local NS = FG.name .. "Sampler"
local CAPACITY = 16384
local MAX_FRAME_S = 2
local FINE_MS, FINE_BINS = 0.25, 256
local WIDE_MS, WIDE_BINS = 4, 256
local FINE_TOP = FINE_MS * FINE_BINS
local BINS = FINE_BINS + WIDE_BINS + 1
local HIST_TOP_MS = FINE_TOP + WIDE_MS * WIDE_BINS - WIDE_MS
local MAX_COLUMNS = 240
local MAX_TIMELINE = 1200
local ROUNDING = 1e-9
local LISTS = { "fps", "low", "ping" }
local PACK_SCALE = 10
local SEAL = LibAPH.CreateSeal({ salt = FG.name, skip = { "name" }, verify = function(run) return S.RunConsistent(run) end })
local PROGRESS = LibAPH.CreateSeal({ salt = FG.name .. " progress", decimals = 4 })
local lists_cache = setmetatable({}, { __mode = "k" })

S.CAPACITY, S.MAX_FRAME_S, S.BINS, S.MAX_COLUMNS = CAPACITY, MAX_FRAME_S, BINS, MAX_COLUMNS

local ring, ring_bin = {}, {}
local hist, session_hist = {}, {}
local head, filled = 0, 0
local window_ms, window_sq = 0, 0

local session = {}
local bucket_frames, bucket_ms, bucket_worst = 0, 0, 0
local columns = { fps = {}, low = {}, ping = {}, count = 0 }
local running = false
local paused = false
local skipped = 0
local rec
local session_line

local function NewLine()
	return { fps = {}, low = {}, ping = {}, step_ms = FG.saved and FG.saved.bucket_ms or 500 }
end

local function BinOf(ms)
	if ms < FINE_TOP then return floor(ms / FINE_MS) + 1 end
	local wide = floor((ms - FINE_TOP) / WIDE_MS)
	if wide >= WIDE_BINS then return BINS end
	return FINE_BINS + wide + 1
end
S.BinOf = BinOf

local function BinMid(bin)
	if bin <= FINE_BINS then return (bin - 0.5) * FINE_MS end
	if bin == BINS then return FINE_TOP + WIDE_MS * WIDE_BINS end
	return FINE_TOP + (bin - FINE_BINS - 0.5) * WIDE_MS
end
S.BinMid = BinMid

local function ClearTable(t)
	for k in pairs(t) do t[k] = nil end
end

function S.Reset()
	for i = 1, BINS do
		hist[i] = 0
		session_hist[i] = 0
	end
	head, filled, window_ms, window_sq = 0, 0, 0, 0
	session.frames, session.ms, session.sq, session.stutters, session.worst = 0, 0, 0, 0, 0
	session.stutter_total, session.ping_sum, session.ping_n, session.ping_max = 0, 0, 0, 0
	session.ping_sq, session.ping_min = 0, 0
	session_line = NewLine()
	bucket_frames, bucket_ms, bucket_worst = 0, 0, 0
	ClearTable(columns.fps)
	ClearTable(columns.low)
	ClearTable(columns.ping)
	columns.count = 0
	skipped = 0
end

local function WindowLimitMs()
	return (FG.saved and FG.saved.graph_seconds or 60) * 1000
end

local function Evict(slot)
	local ms = ring[slot]
	window_ms = window_ms - ms
	window_sq = window_sq - ms * ms
	local bin = ring_bin[slot]
	hist[bin] = hist[bin] - 1
	filled = filled - 1
end

local function Push(ms)
	head = head % CAPACITY + 1
	if filled == CAPACITY then Evict(head) end
	local bin = BinOf(ms)
	ring[head], ring_bin[head] = ms, bin
	hist[bin] = hist[bin] + 1
	filled = filled + 1
	window_ms = window_ms + ms
	window_sq = window_sq + ms * ms
	local limit = WindowLimitMs()
	while window_ms > limit and filled > 1 do
		Evict((head - filled) % CAPACITY + 1)
	end

	session.frames = session.frames + 1
	session.ms = session.ms + ms
	session.sq = session.sq + ms * ms
	session_hist[bin] = session_hist[bin] + 1
	if ms > session.worst then session.worst = ms end
	if ms >= FG.saved.stutter_ms then
		session.stutters = session.stutters + 1
		session.stutter_total = session.stutter_total + ms
	end
	if rec then
		rec.frames = rec.frames + 1
		rec.ms = rec.ms + ms
		rec.sq = rec.sq + ms * ms
		rec.hist[bin] = rec.hist[bin] + 1
		if ms > rec.worst then rec.worst = ms end
		if ms >= FG.saved.stutter_ms then
			rec.stutters = rec.stutters + 1
			rec.stutter_total = rec.stutter_total + ms
		end
	end
end

local function AddPoint(line, fps, low, ping)
	local n = #line.fps + 1
	line.fps[n], line.low[n], line.ping[n] = fps, low, ping
	if n <= MAX_TIMELINE then return end
	local f, l, p = {}, {}, {}
	for i = 1, n, 2 do
		local j = i + 1
		local k = #f + 1
		if line.fps[j] then
			f[k], l[k], p[k] = (line.fps[i] + line.fps[j]) / 2, min(line.low[i], line.low[j]), max(line.ping[i], line.ping[j])
		else
			f[k], l[k], p[k] = line.fps[i], line.low[i], line.ping[i]
		end
	end
	line.fps, line.low, line.ping, line.step_ms = f, l, p, line.step_ms * 2
end
S.AddPoint = AddPoint

local function AddPing(t, ping)
	t.ping_sum, t.ping_n, t.ping_sq = t.ping_sum + ping, t.ping_n + 1, t.ping_sq + ping * ping
	if ping > t.ping_max then t.ping_max = ping end
	if t.ping_n == 1 or ping < t.ping_min then t.ping_min = ping end
end

function S.PingStats(list, first, last, out)
	out = out or {}
	local n, sum, sq, low, high = 0, 0, 0, nil, 0
	for i = first or 1, last or #list do
		local p = list[i]
		if p then
			n, sum, sq = n + 1, sum + p, sq + p * p
			if not low or p < low then low = p end
			if p > high then high = p end
		end
	end
	local avg = n > 0 and sum / n or 0
	out.ping_avg, out.ping_min, out.ping_max = avg, low or 0, high
	out.ping_jitter = n > 0 and sqrt(max(0, sq / n - avg * avg)) or 0
	return out
end

local function PushColumn(fps, low, ping)
	local limit = min(MAX_COLUMNS, max(1, floor(FG.saved.graph_seconds * 1000 / FG.saved.bucket_ms + 0.5)))
	local c = columns.count + 1
	columns.fps[c], columns.low[c], columns.ping[c] = fps, low, ping
	columns.count = c
	if c > limit then
		local drop = c - limit
		for i = 1, limit do
			columns.fps[i], columns.low[i], columns.ping[i] = columns.fps[i + drop], columns.low[i + drop], columns.ping[i + drop]
		end
		for i = limit + 1, c do
			columns.fps[i], columns.low[i], columns.ping[i] = nil, nil, nil
		end
		columns.count = limit
	end
end

local function CloseBucket()
	local fps = bucket_frames * 1000 / bucket_ms
	local low = bucket_worst > 0 and 1000 / bucket_worst or fps
	local ping = GetLatency()
	PushColumn(fps, low, ping)
	AddPoint(session_line, fps, low, ping)
	AddPing(session, ping)
	if rec then
		AddPoint(rec.line, fps, low, ping)
		AddPing(rec, ping)
	end
	local step = bucket_ms
	bucket_frames, bucket_ms, bucket_worst = 0, 0, 0
	if not FG.Graph then return end
	local open = rec and (FG.Graph.IsOpen() or (FG.Summary and FG.Summary.IsShown()) or (FG.Timeline and FG.Timeline.IsShown()))
	local before = open and collectgarbage("count")
	FG.Graph.OnBucket()
	if open then
		rec.window_ms = (rec.window_ms or 0) + step
		local made = collectgarbage("count") - before
		if made > 0 then rec.window_kb = (rec.window_kb or 0) + made end
	end
end

function S.AddFrame(seconds)
	if paused or seconds <= 0 or seconds > MAX_FRAME_S then
		skipped = skipped + 1
		return false
	end
	local ms = seconds * 1000
	Push(ms)
	bucket_frames = bucket_frames + 1
	bucket_ms = bucket_ms + ms
	if ms > bucket_worst then bucket_worst = ms end
	if bucket_ms >= FG.saved.bucket_ms then CloseBucket() end
	return true
end

local function OnFrame()
	S.AddFrame(GetFrameDeltaSeconds())
	if rec and rec.limit_ms and rec.ms >= rec.limit_ms then FG.StopRecording() end
end

function S.Start()
	if running then return false end
	running = true
	EVENT_MANAGER:RegisterForUpdate(NS, 0, OnFrame)
	return true
end

function S.Stop()
	if not running then return false end
	running = false
	EVENT_MANAGER:UnregisterForUpdate(NS)
	return true
end

function S.IsRunning() return running end
function S.SetPaused(on) paused = on == true end
function S.IsPaused() return paused end
function S.Skipped() return skipped end
function S.Columns() return columns end

function S.Budget(target)
	return 1000 / (target - 0.5)
end

local function Build(out, h, n, total_ms, total_sq)
	out.frames = n
	out.seconds = total_ms / 1000
	if n == 0 or total_ms <= 0 then
		out.avg_fps, out.avg_ms, out.low1_fps, out.low01_fps, out.p99_ms, out.max_ms, out.jitter_ms = 0, 0, 0, 0, 0, 0, 0
		out.p50_ms, out.p95_ms, out.p999_ms, out.min_ms, out.median_fps, out.lowest_fps, out.highest_fps = 0, 0, 0, 0, 0, 0, 0
		out.slow_frames, out.slow_pct = 0, 0
		return out
	end
	local avg = total_ms / n
	out.avg_ms = avg
	out.avg_fps = n * 1000 / total_ms
	out.jitter_ms = sqrt(max(0, total_sq / n - avg * avg))

	local want_l1 = max(1, ceil(n * 0.01 - ROUNDING))
	local want_l01 = max(1, ceil(n * 0.001 - ROUNDING))
	local want_p99 = max(1, ceil(n * (1 - 0.99) - ROUNDING))
	local want_p95 = max(1, ceil(n * (1 - 0.95) - ROUNDING))
	local want_p50 = max(1, ceil(n * (1 - 0.5) - ROUNDING))
	local want_p999 = max(1, ceil(n * (1 - 0.999) - ROUNDING))
	local slow_from = BinOf(S.Budget(FG.saved and FG.saved.target_fps or 60)) + 1
	local taken1, sum1, taken01, sum01 = 0, 0, 0, 0
	local seen, slow = 0, 0
	local p99, p95, p50, p999, highest, lowest_bin = 0, 0, 0, 0, 0, nil
	for bin = BINS, 1, -1 do
		local count = h[bin]
		if count > 0 then
			local mid = BinMid(bin)
			if highest == 0 then highest = mid end
			lowest_bin = bin
			if bin >= slow_from then slow = slow + count end
			if taken1 < want_l1 then
				local use = min(count, want_l1 - taken1)
				taken1, sum1 = taken1 + use, sum1 + use * mid
			end
			if taken01 < want_l01 then
				local use = min(count, want_l01 - taken01)
				taken01, sum01 = taken01 + use, sum01 + use * mid
			end
			seen = seen + count
			if p999 == 0 and seen >= want_p999 then p999 = mid end
			if p99 == 0 and seen >= want_p99 then p99 = mid end
			if p95 == 0 and seen >= want_p95 then p95 = mid end
			if p50 == 0 and seen >= want_p50 then p50 = mid end
		end
	end
	out.low1_fps = taken1 > 0 and 1000 / (sum1 / taken1) or 0
	out.low01_fps = taken01 > 0 and 1000 / (sum01 / taken01) or 0
	out.p99_ms, out.p95_ms, out.p50_ms, out.p999_ms = p99, p95, p50, p999
	out.max_ms = highest
	out.min_ms = lowest_bin and BinMid(lowest_bin) or 0
	out.median_fps = out.p50_ms > 0 and 1000 / out.p50_ms or 0
	out.lowest_fps = out.max_ms > 0 and 1000 / out.max_ms or 0
	out.highest_fps = out.min_ms > 0 and 1000 / out.min_ms or 0
	out.slow_frames = slow
	out.slow_pct = out.slow_frames * 100 / n
	return out
end
S.Build = Build

local window_stats, session_stats, rec_stats = {}, {}, {}

function S.WindowStats()
	Build(window_stats, hist, filled, window_ms, window_sq)
	window_stats.current_fps = columns.count > 0 and columns.fps[columns.count] or window_stats.avg_fps
	window_stats.ping = columns.count > 0 and columns.ping[columns.count] or 0
	S.PingStats(columns.ping, 1, columns.count, window_stats)
	return window_stats
end

local function Extras(out, t, line)
	out.stutters, out.worst_ms, out.stutter_total_ms = t.stutters, t.worst, t.stutter_total
	out.ping_avg = t.ping_n > 0 and t.ping_sum / t.ping_n or 0
	out.ping_max, out.ping_min = t.ping_max, t.ping_min
	out.ping_jitter = t.ping_n > 0 and sqrt(max(0, t.ping_sq / t.ping_n - out.ping_avg * out.ping_avg)) or 0
	out.ping_warn = FG.saved.ping_warn_ms
	out.fps, out.low, out.ping, out.step_ms = line.fps, line.low, line.ping, line.step_ms
	out.target_fps, out.stutter_ms = FG.saved.target_fps, FG.saved.stutter_ms
	S.LoadTotals(t.events, out)
	return out
end

function S.SessionStats()
	Build(session_stats, session_hist, session.frames, session.ms, session.sq)
	return Extras(session_stats, session, session_line)
end

function S.StartRecording()
	if rec then return false end
	rec = { frames = 0, ms = 0, sq = 0, stutters = 0, worst = 0, stutter_total = 0, ping_sum = 0, ping_n = 0, ping_max = 0,
		ping_sq = 0, ping_min = 0,
		hist = {}, line = NewLine(), started = GetTimeStamp(), events = FG.saved and FG.saved.record_loads and {} or nil,
		limit_ms = FG.saved and (FG.saved.record_seconds or 0) > 0 and FG.saved.record_seconds * 1000 or nil }
	for i = 1, BINS do rec.hist[i] = 0 end
	return true
end

function S.IsRecording() return rec ~= nil end
function S.Recording() return rec end

local function Copy(value)
	if type(value) ~= "table" then return value end
	local copy = {}
	for key, item in pairs(value) do copy[key] = Copy(item) end
	return copy
end

function S.ProgressCopy()
	if not rec then return nil end
	local copy = Copy(rec)
	copy.seal = nil
	if PROGRESS then PROGRESS.Seal(copy) end
	return copy
end

function S.ResumeRecording(saved_rec)
	if rec or type(saved_rec) ~= "table" or type(saved_rec.hist) ~= "table" or #saved_rec.hist ~= BINS then return false end
	if type(saved_rec.line) ~= "table" or type(saved_rec.line.fps) ~= "table" then return false end
	local tainted = saved_rec.tainted
	if not tainted and (not PROGRESS or PROGRESS.Check(saved_rec) ~= "sealed") then tainted = "progress" end
	rec = saved_rec
	rec.seal, rec.tainted = nil, tainted
	rec.events = rec.events or {}
	return true
end

function FG.Lists(run)
	if type(run) ~= "table" then return {} end
	if not run.packed then return run end
	local lists = lists_cache[run]
	if not lists then
		lists = {}
		for _, key in ipairs(LISTS) do
			if run.packed[key] then lists[key] = LibAPH.UnpackNumbers(run.packed[key], PACK_SCALE) end
		end
		lists_cache[run] = lists
	end
	return lists
end

local function Off(a, b, slack)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) > slack
end

local function Above(a, b, slack)
	return type(a) == "number" and type(b) == "number" and a > b + slack
end

local function Spread(value) return 0.15 + math.abs(value or 0) * 0.01 end

local function Mismatch(fps, ms, share)
	if type(fps) ~= "number" or type(ms) ~= "number" or fps <= 0 then return false end
	local pad = ms * share + 0.05
	return ms + pad < 1000 / (fps + 0.05) or ms - pad > 1000 / max(fps - 0.05, 0.001)
end

function S.RunConsistent(run)
	local avg = run.avg_fps
	if Mismatch(avg, run.avg_ms, 0.01) or Mismatch(run.highest_fps, run.min_ms, 0.01) or Mismatch(run.median_fps, run.p50_ms, 0.01)
		or Mismatch(run.lowest_fps, run.max_ms, 0.04) then
		return false
	end
	local fps_order = { run.lowest_fps, run.low01_fps, run.low1_fps, avg }
	for i = 2, #fps_order do if Above(fps_order[i - 1], fps_order[i], Spread(fps_order[i])) then return false end end
	if Above(run.lowest_fps, run.median_fps, Spread(run.median_fps)) or Above(run.median_fps, run.highest_fps, Spread(run.highest_fps)) then return false end
	local ms_order = { run.min_ms, run.p50_ms, run.p95_ms, run.p99_ms, run.p999_ms, run.max_ms }
	for i = 2, #ms_order do if Above(ms_order[i - 1], ms_order[i], Spread(ms_order[i])) then return false end end
	local stutters, stutter_total = run.stutters, run.stutter_total_ms
	if type(stutters) == "number" and type(stutter_total) == "number" then
		if stutters == 0 and stutter_total > 0.05 then return false end
		if stutters > 0 and run.stutter_ms and stutter_total < stutters * run.stutter_ms - 0.05 * stutters - 0.05 then return false end
		if run.target_fps and run.target_fps > 0 and run.stutter_ms and 1000 / run.target_fps <= run.stutter_ms and Above(stutters, run.slow_frames, 0) then return false end
	end
	if Above(run.ping_min, run.ping_avg, 0.06) or Above(run.ping_avg, run.ping_max, 0.06) then return false end
	if (run.frames or 0) > 0 then
		if avg and run.seconds and math.abs(run.frames - avg * run.seconds) > run.frames * 0.01 + 5 + avg * 0.06 + run.seconds * 0.06 then return false end
		if run.slow_frames and Off(run.slow_pct, run.slow_frames * 100 / run.frames, 0.06) then return false end
	end
	local lists = FG.Lists(run)
	local fps, low, ping = lists.fps or {}, lists.low or {}, lists.ping
	if #fps ~= #low or (ping and #ping > 0 and #ping ~= #fps) then return false end
	for i = 1, #fps do
		if type(fps[i]) ~= "number" or type(low[i]) ~= "number" then return false end
	end
	if #fps >= 6 then
		local fewest, most_low = math.huge, 0
		for i = 2, #fps - 1 do fewest, most_low = min(fewest, low[i]), max(most_low, low[i]) end
		if (run.max_ms or 0) < HIST_TOP_MS and Above(run.lowest_fps, fewest, 0.2 + fewest * 0.05) then return false end
		if Above(most_low, run.highest_fps, Spread(run.highest_fps)) then return false end
	end
	if ping and #ping > 0 and run.ping_max then
		local top, bottom = 0, math.huge
		for i = 1, #ping do
			if type(ping[i]) == "number" then top, bottom = max(top, ping[i]), min(bottom, ping[i]) end
		end
		if Off(run.ping_max, top, 0.06) or Above(run.ping_min, bottom, 0.06) then return false end
	end
	return true
end

function S.RunStatus(run)
	if not SEAL then return "not_sealed" end
	return SEAL.Check(run)
end

function S.LoadTotals(events, out)
	out.loads, out.load_s, out.load_max, out.reloads, out.reload_s, out.reload_max = nil, nil, nil, nil, nil, nil
	out.events = events
	if not events then return out end
	out.loads, out.load_s, out.load_max, out.reloads, out.reload_s, out.reload_max = 0, 0, 0, 0, 0, 0
	for _, event in ipairs(events) do
		if event.k == "reload" then
			out.reloads, out.reload_s, out.reload_max = out.reloads + 1, out.reload_s + event.s, max(out.reload_max, event.s)
		else
			out.loads, out.load_s, out.load_max = out.loads + 1, out.load_s + event.s, max(out.load_max, event.s)
		end
	end
	return out
end
function S.RecordingSeconds() return rec and rec.ms / 1000 or 0 end

function S.RecordingStats()
	if not rec then return nil end
	Build(rec_stats, rec.hist, rec.frames, rec.ms, rec.sq)
	return Extras(rec_stats, rec, rec.line)
end

local function Round(v) return floor(v * 10 + 0.5) / 10 end

function S.NoteLoad(kind, seconds)
	if not (rec and rec.events) then return false end
	rec.events[#rec.events + 1] = { k = kind, at = Round(rec.ms / 1000), s = Round(seconds) }
	return true
end

local function RoundList(list)
	local out = {}
	for i = 1, #list do out[i] = Round(list[i]) end
	return out
end

local RUN_FIELDS = {
	"avg_fps", "median_fps", "low1_fps", "low01_fps", "lowest_fps", "highest_fps",
	"avg_ms", "p50_ms", "p95_ms", "p99_ms", "p999_ms", "max_ms", "min_ms", "jitter_ms",
	"slow_pct", "stutter_total_ms", "ping_avg", "ping_jitter",
}

function S.StopRecording()
	if not rec then return nil end
	local s = S.RecordingStats()
	local run = {
		when = rec.started, seconds = Round(s.seconds), frames = s.frames, slow_frames = s.slow_frames,
		stutters = s.stutters, stutter_ms = s.stutter_ms, target_fps = s.target_fps, ping_max = s.ping_max,
		ping_min = s.ping_min, ping_warn = s.ping_warn,
		step_ms = s.step_ms, fps = RoundList(s.fps), low = RoundList(s.low), ping = RoundList(s.ping),
		events = rec.events, loads = s.loads, reloads = s.reloads,
	}
	for _, key in ipairs(RUN_FIELDS) do run[key] = Round(s[key]) end
	for _, key in ipairs({ "load_s", "load_max", "reload_s", "reload_max" }) do
		if s[key] then run[key] = Round(s[key]) end
	end
	if (rec.window_ms or 0) >= 1000 then
		run.window_s = Round(rec.window_ms / 1000)
		run.window_kbs = Round((rec.window_kb or 0) * 1000 / rec.window_ms)
	end
	run.packed = {}
	for _, key in ipairs(LISTS) do
		if run[key] then
			run.packed[key] = LibAPH.PackNumbers(run[key], PACK_SCALE)
			run[key] = nil
		end
	end
	if rec.tainted or not SEAL then
		LibAPH.RoundNumbers(run, 2)
		run.unsealed = rec.tainted or "no_seal"
	else
		SEAL.Seal(run)
	end
	rec = nil
	return run
end

S.Reset()
