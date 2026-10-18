--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

local AB = ALCBenchmark
local METHOD_NAMES, AlcState, Alc = AB.METHOD_NAMES, AB.AlcState, AB.Alc
local PoolCapacityMB, PoolMB, TIMING = AB.PoolCapacityMB, AB.PoolMB, AB.TIMING

local GUARD = { on = false, driver = "LibAPH_Scheduler", job = "LibAPH_StepCleanup" }

function GUARD.Cleaning()
	if not (AB.test and AB.test.state == "measure" and AB.test.phase) then return false end
	local mode = AB.test.phase.alc_label
	return mode ~= nil and mode ~= "vanilla" and METHOD_NAMES[mode] ~= nil
end

function GUARD.HeldState()
	local state = AlcState()
	if state ~= "vanilla" and METHOD_NAMES[state] then return state .. " (held)" end
	return state
end

function GUARD.OnItsOwn()
	local t = AB.test
	return t.phase.forced_at ~= nil and not t.sim_combat
end

function GUARD.FromAlc(opts)
	local alc = Alc()
	local name = alc and alc.name or "AutoLuaMemoryCleaner"
	return type(opts) == "table" and (opts.source == name or opts.source == "AutoLuaMemoryCleaner")
end

function GUARD.HoldAlcLowMemory()
	local alc = GUARD.alc
	if alc then alc.lowmem_held = not GUARD.Cleaning() or nil end
end

function GUARD.Start()
	if GUARD.on then return end
	GUARD.on = true
	local alc = Alc()
	if alc and alc.start_rescue then
		GUARD.alc = alc
		alc.lowmem_held = true
		alc.rescue_listener = function(result) AB.OnCleanup(result) end
	end
	GUARD.run, GUARD.step = LibAPH.RunCleanup, LibAPH.StepCleanup
	if GUARD.run then
		GUARD.run_wrap = function(opts)
			if GUARD.on and not (GUARD.Cleaning() and GUARD.FromAlc(opts) and (GUARD.forcing or opts.reason == "lowmem" or not AB.test.isolated or GUARD.OnItsOwn())) then
				GUARD.blocked = (GUARD.blocked or 0) + 1
				if GUARD.Cleaning() and GUARD.FromAlc(opts) and AB.test.sim_combat and AB.test.phase.forced_at then AB.PLAYER.Held(AB.test.phase, "alc") end
				return false, "benchmark"
			end
			if GUARD.on then GUARD.forced_run, GUARD.run_action = GUARD.forcing, not GUARD.forcing and AB.PLAYER.Doing() or nil end
			return GUARD.run(opts)
		end
		LibAPH.RunCleanup = GUARD.run_wrap
	end
	if GUARD.step then
		GUARD.step_wrap = function(passes, onDone)
			if GUARD.on and not (GUARD.Cleaning() and LibAPH.IsCleanupRunning and LibAPH.IsCleanupRunning()) then
				GUARD.blocked = (GUARD.blocked or 0) + 1
				if onDone then zo_callLater(onDone, 0) end
				return nil
			end
			return GUARD.step(passes, onDone)
		end
		LibAPH.StepCleanup = GUARD.step_wrap
	end
	local running = LibAPH.GetScheduledJob and LibAPH.GetScheduledJob(GUARD.job)
	if running then running:Cancel() end
	GUARD.paused = LibAPH.__SchedulerTick ~= nil and LibAPH.Schedule ~= nil
	if not GUARD.paused then return end
	EVENT_MANAGER:UnregisterForUpdate(GUARD.driver)
	GUARD.schedule, GUARD.run_or = LibAPH.Schedule, LibAPH.RunOrSchedule
	GUARD.schedule_wrap = function(...)
		local job = GUARD.schedule(...)
		if GUARD.on then EVENT_MANAGER:UnregisterForUpdate(GUARD.driver) end
		return job
	end
	GUARD.run_or_wrap = function(...)
		if GUARD.on then return LibAPH.Schedule(...) end
		return GUARD.run_or(...)
	end
	LibAPH.Schedule, LibAPH.RunOrSchedule = GUARD.schedule_wrap, GUARD.run_or_wrap
end

function GUARD.Frame()
	if not GUARD.on then return end
	GUARD.HoldAlcLowMemory()
	AB.HoldCleaners()
	GUARD.StepJobs()
	GUARD.Collector()
end

function GUARD.Collector()
	local t = AB.test
	local phase = t and t.phase
	local hold = t and t.kind == "alc_only" and t.state == "measure" and phase and not phase.gc_released
	if hold then
		local cap = PoolCapacityMB()
		local pool = cap and PoolMB()
		if pool and pool >= cap * TIMING.save_share then
			phase.gc_released = true
			hold = false
		end
	end
	if hold then
		collectgarbage("stop")
		GUARD.collector_held = true
	elseif GUARD.collector_held then
		GUARD.collector_held = nil
		collectgarbage("restart")
	end
end

function GUARD.StepJobs()
	if GUARD.paused then EVENT_MANAGER:UnregisterForUpdate(GUARD.driver) end
	local job = LibAPH.GetScheduledJob and LibAPH.GetScheduledJob(GUARD.job)
	if not job then return end
	if not GUARD.Cleaning() then
		if not LibAPH.IsCleanupRunning() then job:Cancel() end
		return
	end
	if not GUARD.paused then return end
	local budget = LibAPH.GetSchedulerBudgetMs and LibAPH.GetSchedulerBudgetMs() or 3
	local start = GetGameTimeSeconds() * 1000
	while job:IsRunning() do
		local ok, done = pcall(job.step, job)
		if not ok or done then
			job:Cancel()
			break
		end
		if GetGameTimeSeconds() * 1000 - start >= budget then break end
	end
end

function GUARD.Stop()
	if GUARD.collector_held then
		GUARD.collector_held = nil
		collectgarbage("restart")
	end
	if not GUARD.on then return end
	GUARD.on = false
	if GUARD.alc then
		GUARD.alc.lowmem_held, GUARD.alc.rescue_listener = nil, nil
		GUARD.alc = nil
	end
	AB.ReleaseCleaners()
	if GUARD.run and LibAPH.RunCleanup == GUARD.run_wrap then LibAPH.RunCleanup = GUARD.run end
	if GUARD.step and LibAPH.StepCleanup == GUARD.step_wrap then LibAPH.StepCleanup = GUARD.step end
	if GUARD.schedule and LibAPH.Schedule == GUARD.schedule_wrap then LibAPH.Schedule = GUARD.schedule end
	if GUARD.run_or and LibAPH.RunOrSchedule == GUARD.run_or_wrap then LibAPH.RunOrSchedule = GUARD.run_or end
	if GUARD.paused and LibAPH.GetScheduledCount() > 0 then
		EVENT_MANAGER:RegisterForUpdate(GUARD.driver, 0, LibAPH.__SchedulerTick)
	end
	GUARD.paused = false
end
AB.GUARD = GUARD
