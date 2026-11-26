--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

assert(LibAPH, "LibAPH.lua must be loaded before this file")
local lib = LibAPH
local DRIVER = "LibAPH_LowMemoryRescue"

local START_SHARE = 0.7
local STOP_SHARE = 0.65
local DEEP_SHARE = 0.8
local KILL_SHARE = 0.9
local STEP_KB = 16
local MAX_STEPS = 2000
local BOOST = 3
local CPU_MARGIN_MS = 5
local MIN_FREED_MB = 0.25
local REST_MS = 1000
local DEEP_GAP_MS = 5000
local DEEP_WINDOW_MS = 1000
local DEEP_MIN_DROP_MB = 0.25
local SAMPLE_MS = 250

local rescue

local function LuaMB()
	return collectgarbage("count") / 1024
end

local function PoolMB()
	return GetTotalUserAddOnMemoryPoolUsageMB and GetTotalUserAddOnMemoryPoolUsageMB() or 0
end

local function Call(fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok then zo_callLater(function() error(err, 0) end, 0) end
	return ok and err
end

function lib.GetLowMemoryRescueLines(cap)
	return cap * KILL_SHARE, cap * START_SHARE, cap * STOP_SHARE, cap * DEEP_SHARE
end

function lib.IsLowMemoryRescueRunning(source)
	if not rescue then return false end
	if source then return rescue.sources[source] ~= nil end
	return true
end

local function BudgetMs(used, cap)
	local base = IsConsoleUI() and 2 or 3
	local urgency = zo_clamp((used - cap * START_SHARE) / (cap * (KILL_SHARE - START_SHARE)), 0, 1)
	return base * (1 + (BOOST - 1) * urgency)
end

local function CpuUsedMs()
	local available = GetTotalUserAddOnCPUTimeAvailableEachFrameMS and GetTotalUserAddOnCPUTimeAvailableEachFrameMS()
	if type(available) ~= "number" or available <= 0 or not GetTotalUserAddOnCPUTimeUsedNowMS then return nil end
	return GetTotalUserAddOnCPUTimeUsedNowMS(), available - CPU_MARGIN_MS
end

local function Totals(r)
	return { freedLua = r.freed_lua, freedPool = r.freed_pool, passes = r.passes, deepCleans = r.deep_cleans,
		tookMs = GetGameTimeMilliseconds() - r.started }
end

local function Drop(r, name, reached)
	local source = r.sources[name]
	if not source then return end
	r.sources[name] = nil
	for index = #r.order, 1, -1 do
		if r.order[index] == name then table.remove(r.order, index) end
	end
	if source.onDone then Call(source.onDone, reached, Totals(r)) end
end

local function Finish(reached)
	local r = rescue
	if not r then return end
	rescue = nil
	EVENT_MANAGER:UnregisterForUpdate(DRIVER)
	for index = #r.order, 1, -1 do Drop(r, r.order[index], reached) end
end

local function EndPass(r, now, method, lua, pool)
	local freed_lua, freed_pool = math.max(r.pass_lua - lua, 0), math.max(r.pass_pool - pool, 0)
	r.freed_lua, r.freed_pool, r.passes = r.freed_lua + freed_lua, r.freed_pool + freed_pool, r.passes + 1
	if freed_lua > 0.01 or freed_pool > 0.01 then
		local sources = {}
		for name in pairs(r.sources) do sources[name] = true end
		local result = {
			source = r.order[1], sources = sources, method = method, reason = "lowmem",
			beforeLua = r.pass_lua, afterLua = lua, freedLua = freed_lua,
			beforePool = r.pass_pool, afterPool = pool, freedPool = freed_pool,
			tookMs = now - r.pass_at, cpuMs = r.pass_cpu, finishedAt = now,
		}
		for _, name in ipairs(r.order) do
			local source = r.sources[name]
			if source and source.onPass then Call(source.onPass, result) end
		end
	end
	r.pass_lua, r.pass_pool, r.pass_at, r.pass_cpu = lua, pool, now, 0
	return freed_lua
end

local function ClearSamples(r)
	for index = #r.sample_at, 1, -1 do r.sample_at[index], r.sample_mb[index] = nil, nil end
end

local function Track(r, now, used)
	local at, mb = r.sample_at, r.sample_mb
	local count = #at
	if count == 0 or now - at[count] >= SAMPLE_MS then
		count = count + 1
		at[count], mb[count] = now, used
	end
	while count > 1 and now - at[2] >= DEEP_WINDOW_MS do
		table.remove(at, 1)
		table.remove(mb, 1)
		count = count - 1
	end
end

local function StepsFallBehind(r, now, used)
	local first = r.sample_at[1]
	return first ~= nil and now - first >= DEEP_WINDOW_MS and used > r.sample_mb[1] - DEEP_MIN_DROP_MB
end

local function DeepClean(r, now, cap)
	EndPass(r, now, "rescue", LuaMB(), PoolMB())
	local cpu_start = CpuUsedMs()
	local clock_start = GetGameTimeSeconds() * 1000
	collectgarbage("collect")
	local spent = cpu_start and GetTotalUserAddOnCPUTimeUsedNowMS() - cpu_start or GetGameTimeSeconds() * 1000 - clock_start
	r.pass_at, r.pass_cpu = now - spent, spent
	r.deep_cleans, r.deep_at, r.rest_until = r.deep_cleans + 1, now, nil
	ClearSamples(r)
	local pool = PoolMB()
	EndPass(r, now, "deep", LuaMB(), pool)
	if pool <= cap * STOP_SHARE then Finish(true) end
end

local function Frame()
	local r = rescue
	if not r then return end
	for index = #r.order, 1, -1 do
		local name = r.order[index]
		local can_run = r.sources[name].canRun
		if can_run and not Call(can_run) then Drop(r, name, false) end
	end
	if #r.order == 0 then return Finish(false) end
	local used, cap = LibAPH.GetAddOnMemoryLimitMB()
	if not (used and cap) then return Finish(false) end
	local now = GetGameTimeMilliseconds()
	if used <= cap * STOP_SHARE then
		EndPass(r, now, "rescue", LuaMB(), used)
		return Finish(true)
	end
	Track(r, now, used)
	if used >= cap * DEEP_SHARE and now - (r.deep_at or now - DEEP_GAP_MS) >= DEEP_GAP_MS and StepsFallBehind(r, now, used) then
		return DeepClean(r, now, cap)
	end
	if r.rest_until and now < r.rest_until then return end
	r.rest_until = nil
	local budget = BudgetMs(used, cap)
	local cpu_start, cpu_limit = CpuUsedMs()
	if cpu_start then budget = math.min(budget, cpu_limit - cpu_start) end
	if budget <= 0 then return end
	local clock_start = GetGameTimeSeconds() * 1000
	local finished = false
	for _ = 1, MAX_STEPS do
		if collectgarbage("step", STEP_KB) then
			finished = true
			break
		end
		if GetGameTimeSeconds() * 1000 - clock_start >= budget then break end
		if cpu_start and GetTotalUserAddOnCPUTimeUsedNowMS() - cpu_start >= budget then break end
	end
	r.pass_cpu = r.pass_cpu + (cpu_start and GetTotalUserAddOnCPUTimeUsedNowMS() - cpu_start or GetGameTimeSeconds() * 1000 - clock_start)
	if not finished then return end
	local pool = PoolMB()
	local freed = EndPass(r, now, "rescue", LuaMB(), pool)
	if pool <= cap * STOP_SHARE then return Finish(true) end
	if freed < MIN_FREED_MB then r.rest_until = now + REST_MS end
end

function lib.StartLowMemoryRescue(opts)
	assert(type(opts) == "table" and type(opts.source) == "string", "StartLowMemoryRescue({ source = name })")
	if opts.canRun and not opts.canRun() then return false, "held" end
	local used, cap = opts.used, opts.cap
	if not (used and cap) then used, cap = LibAPH.GetAddOnMemoryLimitMB() end
	if not (used and cap) then return false, "no limit" end
	if used <= cap * STOP_SHARE then return false, "below" end
	local source = { canRun = opts.canRun, onPass = opts.onPass, onDone = opts.onDone }
	if rescue then
		if rescue.sources[opts.source] then return true, "running" end
		rescue.sources[opts.source] = source
		rescue.order[#rescue.order + 1] = opts.source
		return true, "joined"
	end
	local now = GetGameTimeMilliseconds()
	rescue = { started = now, pass_at = now, pass_lua = LuaMB(), pass_pool = PoolMB(), pass_cpu = 0,
		freed_lua = 0, freed_pool = 0, passes = 0, deep_cleans = 0,
		sources = { [opts.source] = source }, order = { opts.source }, sample_at = {}, sample_mb = {} }
	EVENT_MANAGER:RegisterForUpdate(DRIVER, 0, Frame)
	return true, "started"
end

function lib.StopLowMemoryRescue(source)
	local r = rescue
	if not r then return end
	if source then
		Drop(r, source, false)
		if #r.order > 0 then return end
	end
	Finish(false)
end
