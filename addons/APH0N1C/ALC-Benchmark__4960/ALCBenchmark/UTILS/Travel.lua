--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

local AB = ALCBenchmark
local NAME, TIMING, AnnounceTravel, UI, Say, StopTravelWatch = AB.NAME, AB.TIMING, AB.AnnounceTravel, AB.UI, AB.Say, AB.StopTravelWatch
local Pad, StartPhase, LuaMB, PoolMB = AB.Pad, AB.StartPhase, AB.LuaMB, AB.PoolMB

local function PickDestination(skip)
	AB.test.visited[LibAPH.GetCurrentPlace().zone] = true
	if AB.test.home then
		local fixed = AB.test.fixed_dest
		if fixed and not (skip and skip[fixed.zone]) then return fixed end
		local options = {}
		for _, dest in ipairs(LibAPH.GetHouseDestinations()) do
			if dest.zone and dest.zone > 0 and dest.zone ~= AB.test.home.zone and dest.house ~= AB.test.home.house and not (skip and skip[dest.zone]) then
				options[#options + 1] = dest
			end
		end
		if #options == 0 then return nil end
		AB.test.fixed_dest = options[math.random(#options)]
		return AB.test.fixed_dest
	end
	local free = {}
	for _, dest in ipairs(LibAPH.GetHouseDestinations()) do
		if dest.zone and dest.zone > 0 and not AB.test.visited[dest.zone] and not (skip and skip[dest.zone]) then free[#free + 1] = dest end
	end
	if #free == 0 then return nil end
	return free[math.random(#free)]
end

local function StopJumpWatch()
	if AB.test and AB.test.auto_jump then
		AB.test.auto_jump:Cancel()
		AB.test.auto_jump = nil
	end
end

local function AutoTravelLive(token)
	return AB.test ~= nil and AB.test.auto_token == token and AB.test.state == "await_travel" and not AB.test.travel_started
end

local TryAutoTravel

local function AutoTravelFailed(token)
	if not AutoTravelLive(token) then return end
	StopJumpWatch()
	if AB.test.auto_dest then AB.test.visited[AB.test.auto_dest.zone] = nil end
	AB.test.auto_dest = nil
	if AB.test.auto_try > TIMING.auto_retries then
		AB.test.auto_token, AB.test.auto_try = nil, nil
		return AnnounceTravel()
	end
	local wait = {}
	AB.test.auto_token = wait
	if UI.RefreshStatus then UI.RefreshStatus() end
	zo_callLater(function()
		if AutoTravelLive(wait) then TryAutoTravel(AB.test.auto_try + 1) end
	end, TIMING.auto_retry_delay)
end

TryAutoTravel = function(attempt)
	local token = {}
	AB.test.auto_token, AB.test.auto_try = token, attempt
	if not CanJumpToHouseFromCurrentLocation() then return AutoTravelFailed(token) end
	local dest = PickDestination(AB.test.auto_tried)
	if not dest then
		AB.test.auto_token, AB.test.auto_try = nil, nil
		return AnnounceTravel()
	end
	AB.test.visited[dest.zone], AB.test.auto_tried[dest.zone] = true, true
	AB.test.auto_dest = dest
	if UI.RefreshStatus then UI.RefreshStatus() end
	AB.test.auto_jump = LibAPH.RequestHouseJump(dest.house, dest.outside, {
		delayMs = TIMING.auto_delay, timeoutMs = TIMING.auto_timeout,
		isLive = function() return AutoTravelLive(token) end,
		onFailed = function() AutoTravelFailed(token) end,
	})
end

local function StopAutoTravel()
	StopJumpWatch()
	if AB.test then AB.test.auto_dest, AB.test.auto_token, AB.test.auto_try = nil, nil, nil end
end

local function StartAutoTravel()
	if not (UI.On("auto_travel") and AB.test and AB.test.state == "await_travel") then return false end
	if CanJumpToHouseFromCurrentLocation() and not PickDestination() then return false end
	AB.test.auto_tried = {}
	TryAutoTravel(1)
	return true
end

local HOME = { retries = 3, delay = 1000, timeout = 20000, retry_delay = 3000 }

HOME.Here, HOME.Owned = LibAPH.GetCurrentPlace, LibAPH.IsInOwnedHouse

function HOME.AtHome()
	local home = AB.test and AB.test.home
	if not home then return true end
	local here = HOME.Here()
	return here.zone == home.zone and here.house == home.house
end

function HOME.Name()
	return AB.test and AB.test.home and zo_strformat("<<1>>", GetZoneNameById(AB.test.home.zone) or "") or ""
end

function HOME.Announce()
	local text = "Travel back to " .. HOME.Name() .. " so every phase is measured in the same place."
	Say(text)
	LibAPH.SafeCSA(true, "ALC Benchmark", text, 8000)
end

function HOME.Live(token)
	return AB.test ~= nil and AB.test.state == "returning" and AB.test.return_token == token
end

function HOME.Jump(attempt)
	local token = {}
	AB.test.return_token, AB.test.return_try = token, attempt
	local function Failed()
		if not HOME.Live(token) then return end
		if attempt > HOME.retries then
			AB.test.return_token = nil
			return HOME.Announce()
		end
		local wait = {}
		AB.test.return_token = wait
		zo_callLater(function() if HOME.Live(wait) then HOME.Jump(attempt + 1) end end, HOME.retry_delay)
	end
	if not UI.On("auto_travel") then
		AB.test.return_token = nil
		return HOME.Announce()
	end
	AB.test.home_jump = LibAPH.RequestHouseJump(AB.test.home.house, false, {
		delayMs = HOME.delay, timeoutMs = HOME.timeout,
		isLive = function() return HOME.Live(token) end,
		onFailed = Failed,
	})
end

function HOME.Continue(owner, values)
	StopTravelWatch()
	if AB.test.home_from and AB.test.clock then
		AB.test.clock.home_s = AB.test.clock.home_s + (GetGameTimeMilliseconds() - AB.test.home_from) / 1000
		AB.test.clock.home_n = AB.test.clock.home_n + 1
		AB.test.home_from = nil
	end
	AB.test.travel_owner, AB.test.return_values, AB.test.return_token = nil, nil, nil
	Pad.Ensure()
	if owner == AB.test.before_phase and AB.test.before_pending then
		AB.test.before_travel = values
		UI.SaveNow()
		UI.Isolate()
	elseif owner == AB.test.before_phase then
		AB.test.before_values = values
		StartPhase(1)
	elseif owner == AB.test.after_phase and AB.test.after_pending then
		AB.test.after_travel = values
		UI.SaveNow()
		UI.Isolate()
	elseif owner == AB.test.after_phase then
		AB.test.after_values = values
		AB.Finish(false)
	else
		owner.values = values
		StartPhase(AB.test.index + 1)
	end
end

local function AskTravel(owner, values, now)
	owner.measured = values
	owner.travel_values = { lua_pre_travel = LuaMB(), pool_pre_travel = PoolMB() }
	AB.test.travel_owner = owner
	AB.test.state, AB.test.state_at = "await_travel", now
	Pad.Stop()
	EVENT_MANAGER:RegisterForEvent(NAME .. "_Travel", EVENT_PLAYER_DEACTIVATED, function()
		if AB.test and AB.test.state == "await_travel" then
			AB.test.travel_owner.travel_values.lua_pre_travel, AB.test.travel_owner.travel_values.pool_pre_travel = LuaMB(), PoolMB()
			AB.test.travel_started = GetGameTimeMilliseconds()
			StopAutoTravel()
		elseif AB.test and AB.test.state == "returning" then
			AB.test.return_token = nil
			if AB.test.home_jump then AB.test.home_jump:Cancel() end
		end
	end)
	EVENT_MANAGER:RegisterForEvent(NAME .. "_Travel", EVENT_PLAYER_ACTIVATED, function()
		if AB.test and AB.test.state == "await_travel" then
			local arrived = GetGameTimeMilliseconds()
			if AB.test.travel_started and arrived > AB.test.travel_started then
				AB.test.travel_owner.travel_values.load_s = (arrived - AB.test.travel_started) / 1000
			end
			AB.test.travel_started = nil
			AB.test.state, AB.test.state_at = "after_travel", arrived
		elseif AB.test and AB.test.state == "returning" then
			if HOME.AtHome() then
				AB.test.state, AB.test.state_at = "after_return", GetGameTimeMilliseconds()
			else
				HOME.Jump(1)
			end
		end
	end)
	StopAutoTravel()
	if not StartAutoTravel() then AnnounceTravel() end
end
AB.StopAutoTravel, AB.StartAutoTravel, AB.HOME, AB.AskTravel = StopAutoTravel, StartAutoTravel, HOME, AskTravel

local PROGRESS = LibAPH.CreateSeal({ salt = AB.NAME .. " progress", decimals = 4 })

local function Copy(value)
	if type(value) ~= "table" then return value end
	local copy = {}
	for key, item in pairs(value) do copy[key] = Copy(item) end
	return copy
end

function AB.ProgressStatus(state)
	if not PROGRESS then return "not_sealed" end
	return PROGRESS.Check(state)
end

AB.SaveResume = function(for_reload)
	local phases = {}
	for index, phase in ipairs(AB.test.phases) do
		local copy = {}
		for key, value in pairs(phase) do
			if key ~= "stats" and key ~= "placeholder" then copy[key] = value end
		end
		phases[index] = copy
	end
	local state = {
		at = GetTimeStamp(), kind = AB.test.kind, seconds = AB.test.seconds, churn = AB.test.churn, real = AB.test.real, reload = AB.test.reload,
		phases = phases, index = AB.test.index, before_values = AB.test.before_values, metric_name = AB.test.metric_name, target = AB.test.target,
		restore = AB.test.restore, visited = AB.test.visited,
		addons = AB.test.addons, held = AB.test.held, held_cleaners = AB.test.held_cleaners, cleaner_timers = AB.test.cleaner_timers, force_cleaners = AB.test.force_cleaners,
		isolated = AB.test.isolated, isolate = AB.test.state == "await_isolate" or nil, home = AB.test.home, fixed_dest = AB.test.fixed_dest, vanilla_garbage = AB.test.vanilla_garbage, fps = AB.test.fps, continued = AB.test.continued,
		before_pending = AB.test.before_pending, before_travel = AB.test.before_travel, fair_before = AB.test.fair_before,
		after_pending = AB.test.after_pending, after_travel = AB.test.after_travel, fair_after = AB.test.fair_after,
		clock = AB.test.clock, iso_from_ms = AB.test.iso_from_ms, iso_from_ts = AB.test.iso_from_ts, tainted = AB.test.tainted,
		low_warning = AB.test.low_warning, own_cleaning = AB.test.own_cleaning, player = AB.test.player, limit_retries = AB.test.limit_retries,
		hold_mb = AB.test.hold_mb, hold_pool = AB.test.hold_pool, hold_s = AB.test.hold_s,
	}
	if for_reload then
		state = Copy(state)
		if PROGRESS then PROGRESS.Seal(state) end
	end
	AB.saved.resume = state
end

function UI.ResumeSnapshot()
	local kept = AB.saved.resume
	AB.SaveResume()
	local state = AB.saved.resume
	AB.saved.resume = kept
	return state
end

local function AskReload(phase, values, now)
	phase.measured = values
	values.lua_pre_reload, values.pool_pre_reload = LuaMB(), PoolMB()
	AB.test.state, AB.test.state_at = "await_reload", now
	Pad.Stop()
	AB.SaveResume(true)
	zo_callLater(function()
		if AB.test and AB.test.state == "await_reload" then
			values.reload_ms_at, values.reload_ts_at = GetGameTimeMilliseconds(), GetTimeStamp()
			AB.SaveResume(true)
			ReloadUI("ingame")
		end
	end, TIMING.reload_delay)
end
AB.AskReload = AskReload
