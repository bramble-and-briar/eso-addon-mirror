--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

assert(LibAPH, "LibAPH.lua must be loaded before this file")
local LibAPH = LibAPH

local DRIVER = "LibAPH_Scheduler"
local PC_BUDGET_MS = 3
local CONSOLE_BUDGET_MS = 2
local CONSOLE_MARGIN_MS = 5

LibAPH.STOP = {}

local jobs = {}
local by_name = {}
local driving = false
local budget_override
local tick_id = 0

local function NowMs()
	return GetGameTimeSeconds() * 1000
end

function LibAPH.GetSchedulerBudgetMs()
	local console = IsConsoleUI()
	local budget = budget_override or (console and CONSOLE_BUDGET_MS or PC_BUDGET_MS)
	if console then
		local left = GetTotalUserAddOnCPUTimeAvailableEachFrameMS() - GetTotalUserAddOnCPUTimeUsedNowMS() - CONSOLE_MARGIN_MS
		budget = zo_clamp(left, math.min(0, budget), budget)
	end
	return budget
end

function LibAPH.SetSchedulerBudgetMs(ms)
	budget_override = type(ms) == "number" and ms > 0 and ms or nil
end

local Tick

local function StopDriverIfIdle()
	if #jobs == 0 and driving then
		EVENT_MANAGER:UnregisterForUpdate(DRIVER)
		driving = false
	end
end

local function Finish(job, err)
	if not job.running then return end
	job.running = false
	for index = #jobs, 1, -1 do
		if jobs[index] == job then table.remove(jobs, index) end
	end
	if by_name[job.name] == job then by_name[job.name] = nil end
	StopDriverIfIdle()

	local opts = job.opts
	if err ~= nil then
		if opts.onError then
			opts.onError(err, job)
		else
			zo_callLater(function() error(string.format("[LibAPH scheduler] %s: %s", job.name, tostring(err)), 0) end, 0)
		end
	elseif opts.onDone then
		opts.onDone(job)
	end
end

local function RunStep(job)
	local ok, done = pcall(job.step, job)
	if not ok then
		Finish(job, done)
	elseif done then
		Finish(job)
	end
end

Tick = function()
	tick_id = tick_id + 1
	local budget = LibAPH.GetSchedulerBudgetMs()
	if budget <= 0 then return end
	local start = NowMs()
	local index = 1
	local ran_any = false
	while #jobs > 0 do
		if index > #jobs then
			if not ran_any then return end
			index, ran_any = 1, false
		end
		local job = jobs[index]
		if job.opts.oncePerFrame and job.ticked == tick_id then
			index = index + 1
		else
			job.ticked = tick_id
			RunStep(job)
			ran_any = true
			if job.running then index = index + 1 end
			if NowMs() - start >= budget then return end
		end
	end
end

LibAPH.__SchedulerTick = Tick

local function StartDriver()
	if driving then return end
	driving = true
	EVENT_MANAGER:RegisterForUpdate(DRIVER, 0, Tick)
end

local Job = {}
Job.__index = Job

function Job:Cancel()
	if not self.running then return false end
	self.running = false
	for index = #jobs, 1, -1 do
		if jobs[index] == self then table.remove(jobs, index) end
	end
	if by_name[self.name] == self then by_name[self.name] = nil end
	StopDriverIfIdle()
	if self.opts.onCancel then self.opts.onCancel(self) end
	return true
end

function Job:IsRunning()
	return self.running
end

function Job:RunToEnd()
	while self.running do RunStep(self) end
	return self
end

function LibAPH.Schedule(name, step, opts)
	assert(type(name) == "string" and type(step) == "function", "LibAPH.Schedule needs a name and a step function")
	local previous = by_name[name]
	if previous then previous:Cancel() end
	local job = setmetatable({ name = name, step = step, opts = opts or {}, running = true }, Job)
	jobs[#jobs + 1] = job
	by_name[name] = job
	StartDriver()
	return job
end

function LibAPH.RunOrSchedule(name, step, opts)
	local job = LibAPH.Schedule(name, step, opts)
	local budget = LibAPH.GetSchedulerBudgetMs()
	local start = NowMs()
	while job.running and NowMs() - start < budget do RunStep(job) end
	return job
end

function LibAPH.ScheduleLoop(name, items, body, opts)
	opts = opts or {}
	local count = type(items) == "table" and #items or items
	local batch = opts.batch or 1
	local position = 0
	return LibAPH.Schedule(name, function(job)
		for _ = 1, batch do
			position = position + 1
			if position > count then return true end
			local value = type(items) == "table" and items[position] or nil
			if body(position, value, job) == LibAPH.STOP then return true end
		end
		return position >= count
	end, opts)
end

function LibAPH.ScheduleWait(name, condition, onDone, opts)
	opts = opts or {}
	opts.oncePerFrame = true
	opts.onDone = opts.onDone or onDone
	return LibAPH.Schedule(name, function() return condition() and true or false end, opts)
end

function LibAPH.RunInitStages(name, stages)
	local index = 0
	local function Step()
		index = index + 1
		if stages[index] then stages[index]() end
		return index >= #stages
	end
	if Step() then return nil end

	local job_name = name .. "_InitStages"
	local job = LibAPH.Schedule(job_name, Step, { oncePerFrame = true })
	EVENT_MANAGER:RegisterForEvent(job_name, EVENT_PLAYER_ACTIVATED, function()
		EVENT_MANAGER:UnregisterForEvent(job_name, EVENT_PLAYER_ACTIVATED)
		if job:IsRunning() then job:RunToEnd() end
	end)
	return job
end

function LibAPH.InitOnFirstShow(sceneObject, fn)
	if sceneObject:IsShowing() then
		fn()
		return nil
	end
	local deferred = ZO_DeferredInitializingObject:New(sceneObject)
	deferred.OnDeferredInitialize = function() fn() end
	return deferred
end

function LibAPH.GetScheduledJob(name)
	return by_name[name]
end

function LibAPH.IsScheduled(name)
	return by_name[name] ~= nil
end

function LibAPH.GetScheduledCount()
	return #jobs
end

local CLEANUP_JOB = "LibAPH_StepCleanup"
local CLEANUP_STEP_KB = 8
local cleanup_left = 0
local cleanup_waiting = {}

local function FinishCleanup()
	cleanup_left = 0
	local waiting = cleanup_waiting
	cleanup_waiting = {}
	for _, fn in ipairs(waiting) do fn() end
end

function LibAPH.StepCleanup(passes, onDone)
	cleanup_left = math.max(cleanup_left, (passes or 1) + 1)
	if onDone then cleanup_waiting[#cleanup_waiting + 1] = onDone end
	local running = by_name[CLEANUP_JOB]
	if running then return running end
	return LibAPH.Schedule(CLEANUP_JOB, function()
		if collectgarbage("step", CLEANUP_STEP_KB) then cleanup_left = cleanup_left - 1 end
		return cleanup_left <= 0
	end, { onDone = FinishCleanup, onError = FinishCleanup, onCancel = FinishCleanup })
end

function LibAPH.IsStepCleanupRunning()
	return by_name[CLEANUP_JOB] ~= nil
end
