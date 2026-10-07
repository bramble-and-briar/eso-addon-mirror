--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

assert(LibAPH, "LibAPH.lua must be loaded before this file")
local LibAPH = LibAPH

local METHODS = { "automatic", "vanilla", "background", "aggressive", "deep" }
local KNOWN = {}
for _, method in ipairs(METHODS) do KNOWN[method] = true end

local MIN_GROWTH_MB = 2
local MIN_GROWTH_SHARE = 0.05
local SECOND_PASS_SHARE = 0.05
local RECHECK_EVERY = 5
local SETTLE_BEFORE_MS = 500
local SETTLE_AFTER_MS = 200

local last_after_lua, second_share, last_result, running
local menu_runs = 0
local listeners, listener_order = {}, {}

local function PoolMB()
	return GetTotalUserAddOnMemoryPoolUsageMB and GetTotalUserAddOnMemoryPoolUsageMB() or 0
end

local function LuaMB()
	return collectgarbage("count") / 1024
end

local function SafeCall(fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok then zo_callLater(function() error(err, 0) end, 0) end
end

function LibAPH.GetCleanupMethods()
	local copy = {}
	for index, method in ipairs(METHODS) do copy[index] = method end
	return copy
end

function LibAPH.GetMemoryUsageMB()
	return LuaMB(), PoolMB()
end

local function Pick(force, reason, next_menu_run)
	if reason == "lowmem" then return "deep" end
	local lua_mb = LuaMB()
	if not force and last_after_lua then
		local wanted = math.max(MIN_GROWTH_MB, last_after_lua * MIN_GROWTH_SHARE)
		if lua_mb - last_after_lua < wanted then return "vanilla" end
	end
	if IsUnitInCombat("player") or not LibAPH.IsPlayerInMenu() then return "background" end
	if second_share and second_share < SECOND_PASS_SHARE and next_menu_run % RECHECK_EVERY ~= 0 then
		return "aggressive"
	end
	return "deep"
end

function LibAPH.PickCleanupMethod(force, reason)
	return Pick(force, reason, menu_runs + 1)
end

function LibAPH.IsCleanupRunning()
	return running ~= nil
end

function LibAPH.GetLastCleanup()
	return last_result
end

function LibAPH.RegisterCleanupListener(name, fn)
	assert(type(name) == "string" and type(fn) == "function", "RegisterCleanupListener(name, fn)")
	if not listeners[name] then listener_order[#listener_order + 1] = name end
	listeners[name] = fn
end

function LibAPH.UnregisterCleanupListener(name)
	if not listeners[name] then return end
	listeners[name] = nil
	for index = #listener_order, 1, -1 do
		if listener_order[index] == name then table.remove(listener_order, index) end
	end
end

local function Finish(job, before_lua, before_pool)
	zo_callLater(function()
		local after_lua, after_pool = LuaMB(), PoolMB()
		local result = {
			source = job.source,
			sources = job.sources,
			method = job.method,
			picked = job.picked,
			beforeLua = before_lua,
			afterLua = after_lua,
			freedLua = math.max(before_lua - after_lua, 0),
			beforePool = before_pool,
			afterPool = after_pool,
			freedPool = math.max(before_pool - after_pool, 0),
			finishedAt = GetGameTimeMilliseconds(),
		}
		last_after_lua = after_lua
		last_result = result
		running = nil
		for _, fn in ipairs(job.waiting) do SafeCall(fn, result) end
		for _, name in ipairs(listener_order) do
			local fn = listeners[name]
			if fn then SafeCall(fn, result) end
		end
	end, SETTLE_AFTER_MS)
end

local function Collect(job)
	local before_lua, before_pool = LuaMB(), PoolMB()
	local passes = job.method == "aggressive" and 1 or 2
	if job.method == "background" then
		LibAPH.StepCleanup(passes, function() Finish(job, before_lua, before_pool) end)
		return
	end
	local first_freed
	for pass = 1, passes do
		local before_pass = collectgarbage("count")
		collectgarbage("collect")
		local freed_pass = before_pass - collectgarbage("count")
		if pass == 1 then
			first_freed = freed_pass
		elseif job.measure then
			second_share = first_freed > 0 and math.max(freed_pass, 0) / first_freed or 0
		end
	end
	Finish(job, before_lua, before_pool)
end

function LibAPH.RunCleanup(opts)
	opts = opts or {}
	local method = opts.method or "automatic"
	if not KNOWN[method] then return false, "unknown" end
	local source = opts.source or "unknown"

	if running then
		if not running.sources[source] then running.sources[source] = true end
		if opts.onDone then running.waiting[#running.waiting + 1] = opts.onDone end
		return true, "joined"
	end

	local picked
	if method == "vanilla" then
		if not opts.force then return false, "vanilla" end
		method = "background"
	elseif method == "automatic" then
		method = Pick(opts.force, opts.reason, menu_runs + 1)
		if method == "vanilla" then return false, "vanilla" end
		if opts.reason ~= "lowmem" and (method == "deep" or method == "aggressive") then menu_runs = menu_runs + 1 end
		picked = method
	end

	local job = {
		source = source,
		sources = { [source] = true },
		method = method,
		picked = picked,
		measure = picked == "deep",
		waiting = { opts.onDone },
	}
	running = job
	zo_callLater(function()
		local ok, err = pcall(Collect, job)
		if ok then return end
		if running == job then running = nil end
		error(err, 0)
	end, SETTLE_BEFORE_MS)
	return true, method
end
