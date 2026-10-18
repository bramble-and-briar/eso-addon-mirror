--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

local AB = ALCBenchmark
local NAME, UI, Say, Fmt, LuaMB, PoolMB, PoolCapacityMB, Alc = AB.NAME, AB.UI, AB.Say, AB.Fmt, AB.LuaMB, AB.PoolMB, AB.PoolCapacityMB, AB.Alc
local MakeGarbage, ChunkKB, CpuRoom, FILL_MB_PER_FRAME = AB.MakeGarbage, AB.ChunkKB, AB.CpuRoom, AB.FILL_MB_PER_FRAME

local LOAD = {}
local DRIVER = NAME .. "_LoadTest"
local SIDES = {
	{ key = "vanilla", name = "Vanilla" },
	{ key = "alc", name = "ALC" },
	{ key = "mgc", name = "Memory Garbage Collector", short = "MGC" },
	{ key = "shissu", name = "Shissu's LUA Memory", short = "Shissu" },
}
local SIDE_BY_KEY = {}
for _, side in ipairs(SIDES) do SIDE_BY_KEY[side.key] = side end
local DEFAULTS = { per_side = 15, warmup = 2, garbage_pc = 100, garbage_console = 30 }
local LIMITS = { per_side = { 3, 100 }, warmup = { 0, 10 }, garbage = { 0, 500 } }
local TIMING = {
	settle_ms = 3000, jump_delay_ms = 1000, jump_timeout_ms = 20000, jump_retries = 3, retry_delay_ms = 3000,
	clean_timeout_ms = 15000, max_load_ms = 600000, draw_ms = 1000, round_trip_s = 30,
}
local POOL_SAFE_SHARE = 0.65
local SAVED_MAX = 20
local SEAL = LibAPH.CreateSeal({ salt = NAME .. " loading", skip = { "name" } })

LOAD.SIDES, LOAD.SIDE_BY_KEY, LOAD.DEFAULTS, LOAD.LIMITS, LOAD.TIMING = SIDES, SIDE_BY_KEY, DEFAULTS, LIMITS, TIMING

function LOAD.SideName(key, short)
	local side = SIDE_BY_KEY[key]
	if not side then return tostring(key) end
	return short and side.short or side.name
end

function LOAD.Saved()
	if not AB.saved then return {} end
	AB.saved.loading_tests = AB.saved.loading_tests or {}
	return AB.saved.loading_tests
end

function LOAD.Setting(key)
	local saved = AB.saved and AB.saved["load_" .. key]
	if key == "garbage" then
		local fallback = IsConsoleUI() and DEFAULTS.garbage_console or DEFAULTS.garbage_pc
		return math.floor(zo_clamp(tonumber(saved) or fallback, LIMITS.garbage[1], LIMITS.garbage[2]))
	end
	return math.floor(zo_clamp(tonumber(saved) or DEFAULTS[key], LIMITS[key][1], LIMITS[key][2]))
end

function LOAD.SetSetting(key, number)
	local limits = LIMITS[key]
	AB.saved["load_" .. key] = math.floor(zo_clamp(number, limits[1], limits[2]))
end

function LOAD.Blocked(key)
	if key == "vanilla" then return nil end
	if key == "alc" then
		local why = UI.AlcBlocked()
		if why then return why end
		local alc = Alc()
		if type(alc.run_manual_cleanup) ~= "function" then return "this ALC version has no cleanup call the benchmark can use" end
		return nil
	end
	return AB.CleanerBlocked(key)
end

function LOAD.Picked(key)
	local picked = AB.saved and AB.saved.load_sides
	return not (type(picked) == "table" and picked[key] == false)
end

function LOAD.SetPicked(key, on)
	AB.saved.load_sides = AB.saved.load_sides or {}
	AB.saved.load_sides[key] = on and true or false
end

function LOAD.Chosen()
	local list = {}
	for _, side in ipairs(SIDES) do
		if LOAD.Picked(side.key) and not LOAD.Blocked(side.key) then list[#list + 1] = side.key end
	end
	return list
end

local function PickDestination(home)
	local inside, any = {}, {}
	for _, dest in ipairs(LibAPH.GetHouseDestinations()) do
		if dest.zone and dest.zone > 0 and dest.zone ~= home.zone and dest.house ~= home.house then
			any[#any + 1] = dest
			if dest.owned and not dest.outside then inside[#inside + 1] = dest end
		end
	end
	local pool = #inside > 0 and inside or any
	if #pool == 0 then return nil end
	return pool[math.random(#pool)]
end

function LOAD.StartBlocked()
	if AB.test or LOAD.run then return "a test is already running" end
	if #LOAD.Chosen() == 0 then return "pick at least one side" end
	if not LibAPH.IsInOwnedHouse() then return "start inside a house you own" end
	if not CanJumpToHouseFromCurrentLocation() then return "you cannot travel to a house from here" end
	if not PickDestination(LibAPH.GetCurrentPlace()) then return "you need a second house to travel to" end
	return nil
end

function LOAD.Plan(sides, per_side, warmup)
	local queue = {}
	for _ = 1, warmup do queue[#queue + 1] = { warm = true } end
	local count = #sides
	for round = 1, per_side do
		local order = {}
		for index = 1, count do order[index] = sides[(index - 1 + round - 1) % count + 1] end
		for _, key in ipairs(order) do queue[#queue + 1] = { round = round, side = key } end
	end
	return queue
end

function LOAD.EstimateMinutes(sides, per_side, warmup)
	return math.max(1, math.floor(((#sides * per_side) + warmup) * TIMING.round_trip_s / 60 + 0.5))
end

local function Sorted(values)
	local copy = {}
	for index, value in ipairs(values) do copy[index] = value end
	table.sort(copy)
	return copy
end

local function Quantile(sorted, share)
	local count = #sorted
	if count == 0 then return nil end
	if count == 1 then return sorted[1] end
	local at = 1 + (count - 1) * share
	local low = math.floor(at)
	local high = math.min(low + 1, count)
	return sorted[low] + (sorted[high] - sorted[low]) * (at - low)
end

function LOAD.Median(values)
	return Quantile(Sorted(values), 0.5)
end

local function MeanAndError(values)
	local count = #values
	if count == 0 then return nil, nil end
	local sum = 0
	for _, value in ipairs(values) do sum = sum + value end
	local mean = sum / count
	if count < 2 then return mean, nil end
	local squares = 0
	for _, value in ipairs(values) do squares = squares + (value - mean) ^ 2 end
	return mean, math.sqrt(squares / (count - 1)) / math.sqrt(count)
end

local SAME_SHARE, SAME_MIN_S = 0.05, 0.5

function LOAD.Reference(record)
	for _, key in ipairs(record.sides or {}) do
		if key == "vanilla" then return key end
	end
	return record.sides and record.sides[1]
end

function LOAD.SideStats(record, key)
	local loads, backs, lua, pool, freed, after = {}, {}, {}, {}, {}, {}
	for _, sample in ipairs(record.samples or {}) do
		if sample.side == key then
			loads[#loads + 1] = sample.load_s
			if sample.back_s then backs[#backs + 1] = sample.back_s end
			if sample.lua_mb then lua[#lua + 1] = sample.lua_mb end
			if sample.pool_mb then pool[#pool + 1] = sample.pool_mb end
			if sample.freed_mb then freed[#freed + 1] = sample.freed_mb end
			if sample.lua_after then after[#after + 1] = sample.lua_after end
		end
	end
	local sorted = Sorted(loads)
	return {
		n = #loads,
		median = Quantile(sorted, 0.5), low = Quantile(sorted, 0.25), high = Quantile(sorted, 0.75),
		fastest = sorted[1], slowest = sorted[#sorted],
		back = LOAD.Median(backs), lua = LOAD.Median(lua), pool = LOAD.Median(pool), freed = LOAD.Median(freed), after = LOAD.Median(after),
	}
end

function LOAD.Pairs(record, key, ref)
	local by_round = {}
	for _, sample in ipairs(record.samples or {}) do
		by_round[sample.round] = by_round[sample.round] or {}
		by_round[sample.round][sample.side] = sample.load_s
	end
	local diffs, faster = {}, 0
	for _, sides in pairs(by_round) do
		if sides[key] and sides[ref] then
			local diff = sides[key] - sides[ref]
			diffs[#diffs + 1] = diff
			if diff < 0 then faster = faster + 1 end
		end
	end
	local mean, err = MeanAndError(diffs)
	return { n = #diffs, mean = mean, err = err, faster = faster }
end

function LOAD.Margin(ref_median)
	return math.max(SAME_MIN_S, SAME_SHARE * (ref_median or 0))
end

function LOAD.Verdict(pairs_stats, ref_median)
	if pairs_stats.n == 0 or not pairs_stats.mean then return "no pairs" end
	if not pairs_stats.err then return "unsettled" end
	local margin, range, mean = LOAD.Margin(ref_median), 2 * pairs_stats.err, pairs_stats.mean
	if math.abs(mean) + range <= margin then return "same" end
	if math.abs(mean) > range then
		if math.abs(mean) <= margin then return "same" end
		return mean < 0 and "faster" or "slower"
	end
	return "unsettled"
end

local function Here()
	return LibAPH.GetCurrentPlace()
end

local function AtHome(run)
	local here = Here()
	return here.zone == run.home.zone and here.house == run.home.house
end

local function SaveRecord(run)
	local record = run.record
	if not run.saved_once then
		local list = LOAD.Saved()
		table.insert(list, 1, record)
		while #list > SAVED_MAX do table.remove(list) end
		run.saved_once = true
	end
end

local function StatusText(run)
	local entry = run.queue[run.index]
	local done = #run.record.samples
	local total = #run.record.sides * run.record.per_side
	local head = string.format("Loading screen test: %d of %d loads", done, total)
	if not entry then return head end
	local who = entry.warm and "warm-up" or (LOAD.SideName(entry.side) .. ", round " .. entry.round)
	local doing = run.doing or "waiting"
	return string.format("%s. Now: %s, %s", head, who, doing)
end

function LOAD.StatusText()
	return LOAD.run and StatusText(LOAD.run) or nil
end

local function Refresh(run, force)
	local now = GetGameTimeMilliseconds()
	if not force and now < (run.next_draw or 0) then return end
	run.next_draw = now + TIMING.draw_ms
	UI.SetStatusLine(StatusText(run))
	if UI.IsShown() and AB.view.page == "loading" and UI.Draw then UI.Draw() end
end

local Release, Finish, NextEntry, Jump

local function Hold(run)
	local alc = Alc()
	if alc and alc.settings then
		run.restore = { mode = alc.settings.cleanup_mode, pool_travel = alc.settings.auto_clear_pool_on_teleport, afk = alc.settings.afk_reload }
		AB.HoldAlcReloads(alc)
		alc.lowmem_held = true
	end
	run.held = LibAPH.HoldGameSettings()
	AB.saved.load_restore, AB.saved.load_held = run.restore, run.held
	LOAD.lib_run, LOAD.lib_step = LibAPH.RunCleanup, LibAPH.StepCleanup
	if LOAD.lib_run then
		LOAD.run_wrap = function(opts)
			if LOAD.run and not LOAD.allow then return false, "benchmark" end
			return LOAD.lib_run(opts)
		end
		LibAPH.RunCleanup = LOAD.run_wrap
	end
	if LOAD.lib_step then
		LOAD.step_wrap = function(passes, onDone)
			if LOAD.run and not LOAD.allow then
				if onDone then zo_callLater(onDone, 0) end
				return nil
			end
			return LOAD.lib_step(passes, onDone)
		end
		LibAPH.StepCleanup = LOAD.step_wrap
	end
	AB.HoldCleaners()
end

Release = function(run)
	EVENT_MANAGER:UnregisterForUpdate(DRIVER)
	EVENT_MANAGER:UnregisterForEvent(DRIVER, EVENT_PLAYER_DEACTIVATED)
	EVENT_MANAGER:UnregisterForEvent(DRIVER, EVENT_PLAYER_ACTIVATED)
	if run.jump then run.jump:Cancel() end
	run.jump = nil
	collectgarbage("restart")
	LOAD.allow = nil
	if LOAD.run_wrap and LibAPH.RunCleanup == LOAD.run_wrap then LibAPH.RunCleanup = LOAD.lib_run end
	if LOAD.step_wrap and LibAPH.StepCleanup == LOAD.step_wrap then LibAPH.StepCleanup = LOAD.lib_step end
	LOAD.run_wrap, LOAD.step_wrap = nil, nil
	local alc = Alc()
	if alc then alc.lowmem_held = nil end
	AB.ReleaseCleaners()
	AB.Restore(run.restore)
	LibAPH.ReleaseGameSettings(run.held)
	AB.saved.load_restore, AB.saved.load_held = nil, nil
end

Finish = function(note)
	local run = LOAD.run
	if not run then return end
	Release(run)
	LOAD.run = nil
	local record = run.record
	record.running = nil
	record.rounds_done = run.rounds_done
	if note then record.stopped, record.note = true, note end
	if SEAL then SEAL.Seal(record) else LibAPH.RoundNumbers(record, 2) end
	LOAD.shown = record
	UI.HideStatusLine()
	Say(note and ("Loading screen test stopped: " .. note .. ".") or "Loading screen test done. The results are on the Loading Screens page.")
	if UI.SetPage then
		UI.Show()
		UI.SetPage("loading")
	end
end

function LOAD.Stop(note)
	Finish(note or "stopped by you")
end

local function Retry(run, target, attempt)
	if attempt > TIMING.jump_retries then
		return Finish("could not travel to " .. (target == "home" and run.home_text or run.dest.text))
	end
	run.doing = string.format("travel did not start, trying again (%d of %d)", attempt, TIMING.jump_retries)
	local token = {}
	run.retry_token = token
	zo_callLater(function()
		if LOAD.run == run and run.retry_token == token then Jump(run, target, attempt + 1) end
	end, TIMING.retry_delay_ms)
end

Jump = function(run, target, attempt)
	attempt = attempt or 1
	local token = {}
	run.jump_token = token
	local house, outside = run.dest.house, run.dest.outside
	if target == "home" then house, outside = run.home.house, false end
	run.state = target == "home" and "to_home" or "to_dest"
	run.doing = target == "home" and ("travelling back to " .. run.home_text) or ("travelling to " .. run.dest.text)
	if run.jump then run.jump:Cancel() end
	run.jump = LibAPH.RequestHouseJump(house, outside, {
		delayMs = TIMING.jump_delay_ms, timeoutMs = TIMING.jump_timeout_ms,
		isLive = function() return LOAD.run == run and run.jump_token == token end,
		onFailed = function()
			if LOAD.run ~= run or run.jump_token ~= token then return end
			Retry(run, target, attempt)
		end,
	})
end

local function CommitSample(run)
	local sample = run.sample
	run.sample = nil
	if not sample or sample.warm then return end
	sample.warm, sample.before_clean = nil, nil
	local samples = run.record.samples
	samples[#samples + 1] = sample
	local entry = run.queue[run.index]
	if entry and entry.round and entry.round > run.rounds_done then
		local complete = true
		for _, key in ipairs(run.record.sides) do
			local found = false
			for _, s in ipairs(samples) do if s.round == entry.round and s.side == key then found = true end end
			if not found then complete = false end
		end
		if complete then run.rounds_done = entry.round end
	end
	run.record.rounds_done = run.rounds_done
end

local function StartClean(run, now)
	local entry = run.queue[run.index]
	local sample = run.sample
	sample.before_clean = LuaMB()
	if entry.warm or entry.side == "vanilla" then
		run.state = "ready"
		return
	end
	if entry.side == "alc" then
		local alc = Alc()
		LOAD.allow = true
		run.clean_from = now
		run.state = "cleaning"
		run.doing = "ALC is cleaning"
		local ok = pcall(alc.run_manual_cleanup, false, nil, true)
		if not ok then sample.error = true end
		return
	end
	local ok, freed, cleaned = AB.RunCleaner(entry.side)
	if not cleaned and AB.ForcingCleaners() then
		freed, cleaned = AB.ForceClean()
		sample.forced = cleaned or nil
	end
	if not ok then sample.error = true end
	sample.freed_mb = freed or 0
	run.state = "ready"
end

local function Frame()
	local run = LOAD.run
	if not run then return end
	if IsUnitInCombat("player") then return Finish("combat started") end
	local now = GetGameTimeMilliseconds()
	AB.HoldCleaners()
	local alc = Alc()
	if alc and alc.settings and not LOAD.allow then alc.lowmem_held = true end
	if run.state == "settle" then
		if now - run.state_at >= TIMING.settle_ms then NextEntry(run, now) end
	elseif run.state == "fill" then
		local cap = PoolCapacityMB()
		local pool = cap and PoolMB()
		if run.fill_left <= 0.01 or (pool and pool >= cap * POOL_SAFE_SHARE) then
			run.sample.made_mb = run.sample.made_mb or 0
			StartClean(run, now)
		elseif CpuRoom() then
			local made = MakeGarbage(math.min(FILL_MB_PER_FRAME, run.fill_left))
			run.fill_left = run.fill_left - math.max(made, 0.01)
			run.sample.made_mb = (run.sample.made_mb or 0) + made
		end
	elseif run.state == "cleaning" then
		local done = not LibAPH.IsCleanupRunning()
		if done or now - run.clean_from >= TIMING.clean_timeout_ms then
			LOAD.allow = nil
			local last = LibAPH.GetLastCleanup and LibAPH.GetLastCleanup()
			run.sample.method = last and last.finishedAt and last.finishedAt >= run.clean_from and last.method or "none"
			run.sample.freed_mb = math.max((run.sample.before_clean or 0) - LuaMB(), 0)
			if not done then run.sample.timed_out = true end
			run.state = "ready"
		end
	elseif run.state == "ready" then
		if (run.record.garbage_mb or 0) > 0 then collectgarbage("stop") end
		Jump(run, "dest")
	elseif run.state == "away" then
		if now - run.state_at >= TIMING.settle_ms then
			run.sample.lua_after = LuaMB()
			Jump(run, "home")
		end
	end
	Refresh(run)
end

NextEntry = function(run, now)
	run.index = run.index + 1
	local entry = run.queue[run.index]
	if not entry then return Finish() end
	run.sample = { round = entry.round, side = entry.side, warm = entry.warm or nil }
	run.fill_left = entry.warm and 0 or run.record.garbage_mb
	if run.fill_left > 0 then collectgarbage("stop") end
	run.state, run.state_at = "fill", now
	run.doing = run.fill_left > 0 and string.format("making %s MB of garbage", Fmt(run.fill_left)) or "getting ready"
	Refresh(run, true)
end

local function OnDeactivated()
	local run = LOAD.run
	if not run then return end
	if run.state == "to_dest" then
		run.sample.lua_mb, run.sample.pool_mb = LuaMB(), PoolMB()
		collectgarbage("restart")
		run.load_from, run.state = GetGameTimeMilliseconds(), "loading"
	elseif run.state == "to_home" then
		run.load_from, run.state = GetGameTimeMilliseconds(), "loading_home"
	end
end

local function OnActivated()
	local run = LOAD.run
	if not run then return end
	local now = GetGameTimeMilliseconds()
	local took = run.load_from and now - run.load_from
	if took and (took <= 0 or took > TIMING.max_load_ms) then took = nil end
	if run.state == "loading" then
		run.sample.load_s = took and took / 1000 or nil
		if not run.sample.load_s then return Finish("a loading screen could not be timed") end
		run.state, run.state_at, run.doing = "away", now, "settling after the loading screen"
	elseif run.state == "loading_home" then
		run.sample.back_s = took and took / 1000 or nil
		if not AtHome(run) then return Jump(run, "home") end
		CommitSample(run)
		run.state, run.state_at, run.doing = "settle", now, "settling at home"
	end
	run.load_from = nil
	Refresh(run, true)
end

function LOAD.Start()
	local why = LOAD.StartBlocked()
	if why then return Say("Cannot start the loading screen test: " .. why .. ".") end
	if IsUnitInCombat("player") then return Say("Leave combat first.") end
	ChunkKB()
	local sides = LOAD.Chosen()
	local per_side, warmup, garbage = LOAD.Setting("per_side"), LOAD.Setting("warmup"), LOAD.Setting("garbage")
	local home = Here()
	local dest = PickDestination(home)
	local record = {
		id = (AB.saved.next_load_id or 0) + 1,
		when = GetDateStringFromTimestamp(GetTimeStamp()) .. " " .. GetTimeString(),
		platform = (IsConsoleUI() and "console" or "PC") .. (IsInGamepadPreferredMode() and ", gamepad UI" or ", keyboard UI"),
		fps = not IsConsoleUI() and (LibAPH.GetFpsCap() or "uncapped") or nil,
		sides = sides, per_side = per_side, warmup = warmup, garbage_mb = garbage,
		home = zo_strformat("<<1>>", GetZoneNameById(home.zone) or ""), dest = dest.text,
		force_cleaners = AB.ForcingCleaners() or nil,
		samples = {}, rounds_done = 0, running = true,
	}
	AB.saved.next_load_id = record.id
	local run = {
		record = record, home = home, dest = dest, home_text = record.home,
		queue = LOAD.Plan(sides, per_side, warmup), index = 0, rounds_done = 0,
	}
	LOAD.run = run
	LOAD.shown = record
	Hold(run)
	SaveRecord(run)
	EVENT_MANAGER:RegisterForEvent(DRIVER, EVENT_PLAYER_DEACTIVATED, OnDeactivated)
	EVENT_MANAGER:RegisterForEvent(DRIVER, EVENT_PLAYER_ACTIVATED, OnActivated)
	EVENT_MANAGER:RegisterForUpdate(DRIVER, 0, Frame)
	local names = {}
	for _, key in ipairs(sides) do names[#names + 1] = LOAD.SideName(key) end
	Say(string.format("Loading screen test: %s, %d loads each to %s and back, %d warm-up loads first, %s MB of garbage before each load. Roughly %d min.",
		table.concat(names, ", "), per_side, dest.text, warmup, Fmt(garbage, 0), LOAD.EstimateMinutes(sides, per_side, warmup)))
	UI.Hide()
	run.state, run.state_at = "settle", GetGameTimeMilliseconds()
	Refresh(run, true)
end

function LOAD.Delete(record)
	local list = LOAD.Saved()
	for index = #list, 1, -1 do
		if list[index] == record then table.remove(list, index) end
	end
	if LOAD.shown == record then LOAD.shown = nil end
end

function LOAD.Clear()
	if AB.saved then AB.saved.loading_tests = {} end
	LOAD.shown = nil
end

function LOAD.SealStatus(record)
	if record.running then return "running" end
	if not SEAL then return "not_sealed" end
	return SEAL.Check(record)
end

function LOAD.Invalid(record)
	if not SEAL or record.running then return false end
	local _, invalid = UI.SealMarkers(record, LOAD.SealStatus(record))
	return invalid
end

local function Recover()
	if not AB.saved or LOAD.run then return end
	if AB.saved.load_restore or AB.saved.load_held then
		AB.Restore(AB.saved.load_restore)
		LibAPH.ReleaseGameSettings(AB.saved.load_held)
		AB.saved.load_restore, AB.saved.load_held = nil, nil
	end
	for _, record in ipairs(LOAD.Saved()) do
		if record.running then
			record.running, record.stopped, record.note = nil, true, "cut off by a reload, a crash or the game closing"
			record.unsealed = "it was cut off before it finished"
		end
	end
end

EVENT_MANAGER:RegisterForEvent(DRIVER .. "_Recover", EVENT_PLAYER_ACTIVATED, function()
	EVENT_MANAGER:UnregisterForEvent(DRIVER .. "_Recover", EVENT_PLAYER_ACTIVATED)
	Recover()
end)

local start_ab, start_run = AB.StartAB, AB.StartRun
AB.StartAB = function(...)
	if LOAD.run then return Say("The loading screen test is running; stop it first from the menu.") end
	return start_ab(...)
end
AB.StartRun = function(...)
	if LOAD.run then return Say("The loading screen test is running; stop it first from the menu.") end
	return start_run(...)
end

AB.LOAD = LOAD
