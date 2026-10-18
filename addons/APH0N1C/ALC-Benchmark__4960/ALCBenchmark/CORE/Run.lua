--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

local AB = ALCBenchmark
local Tint, BAD, GOOD, TIMING, UI, HOME = AB.Tint, AB.BAD, AB.GOOD, AB.TIMING, AB.UI, AB.HOME
local Fmt, ChunkKB, Alc, TRAVEL_TEXT = AB.Fmt, AB.ChunkKB, AB.Alc, AB.TRAVEL_TEXT
local GUARD, Finish, Record, Sample, EndSample, Finalize, AskTravel = AB.GUARD, AB.Finish, AB.Record, AB.Sample, AB.EndSample, AB.Finalize, AB.AskTravel
local BeginMeasure, Hold, FILL_MB_PER_FRAME, PhaseChurn = AB.BeginMeasure, AB.Hold, AB.FILL_MB_PER_FRAME, AB.PhaseChurn
local MakeGarbage, PhaseExtra, AskReload, StartPhase, LuaMB, PoolMB = AB.MakeGarbage, AB.PhaseExtra, AB.AskReload, AB.StartPhase, AB.LuaMB, AB.PoolMB
local LiveColumns, PoolCapacityMB, Say, History, ShowSaved, Restore = AB.LiveColumns, AB.PoolCapacityMB, AB.Say, AB.History, AB.ShowSaved, AB.Restore
local Compare, NAME, OnCleanup = AB.Compare, AB.NAME, AB.OnCleanup
local NewStats, MethodLabel, GAME_ONLY = AB.NewStats, AB.MethodLabel, AB.GAME_ONLY
local PLAYER = AB.PLAYER


local function PhaseNote(phase, text)
	local stats = phase.stats
	phase.notes = phase.notes or {}
	for _, note in ipairs(phase.notes) do
		if note.text == text then return end
	end
	phase.notes[#phase.notes + 1] = { text = text, at = stats and math.floor((GetGameTimeMilliseconds() - stats.started) / 1000 + 0.5) or 0 }
end
local WATCHED_ELSEWHERE = { fill = true, measure = true, await_isolate = true, await_reload = true }

local function Slowed(phase)
	local share = UI.GarbageShare()
	if share < 1 then phase.slowed = math.min(phase.slowed or 1, share) end
	return share
end

local FillHoldStep

local function FillLeft()
	local t = AB.test
	local held = #t.hold * ChunkKB() / 1024
	if t.hold_pool then
		local pool = PoolMB()
		return math.min(t.hold_pool - (pool or 0), t.hold_pool - held)
	end
	return (t.hold_mb or 0) - held
end

FillHoldStep = function(phase, now)
	local t = AB.test
	local left = FillLeft()
	local fits = UI.FillFitsMB(left)
	local step = math.min(FILL_MB_PER_FRAME, left, fits)
	if step < 0.01 or now - t.state_at >= TIMING.fill_timeout then
		if left >= 0.5 then
			PhaseNote(phase, string.format("the fill stopped %s MB short of its target (%s)", Fmt(left), fits < left and "the add-on memory limit" or "it ran out of time"))
		end
		t.fill_done_at = now
		return
	end
	if AB.CpuRoom() then Hold(t.hold, step) end
end

local function FocusText()
	local away = 0
	local function Add(stats, values)
		away = away + ((stats and stats.away_s) or (values and values.away_s) or 0)
	end
	Add(AB.test.before, AB.test.before_values)
	for _, phase in ipairs(AB.test.phases) do Add(phase.stats, phase.values or phase.measured) end
	Add(AB.test.after, AB.test.after_values)
	if not DoesGameHaveFocus() then return Tint(string.format("Game in background (%d s so far).", away), BAD) end
	local text = Tint("Game focused.", GOOD)
	if away > 0 then text = text .. string.format(" In background %d s so far.", away) end
	return text
end

function UI.StepText()
	local test = AB.test
	if not test then return "" end
	local total = #(test.phases or {}) + 2
	local step = (test.state == "after" or (test.index or 0) > #(test.phases or {})) and total or math.min((test.index or 0) + 1, total - 1)
	return Tint(string.format("Test %d/%d", step, total), AB.SAME) .. ". "
end

local function StatusBody(now)
	local phase = AB.test.phase
	if AB.test.state == "before" then return "Before: measuring normal play, " .. Tint(string.format("%d / %d s", math.floor((now - AB.test.state_at) / 1000), TIMING.before / 1000), BAD) end
	if AB.test.state == "after" then return "After: measuring normal play, " .. Tint(string.format("%d / %d s", math.floor((now - AB.test.state_at) / 1000), TIMING.before / 1000), BAD) end
	local outside = AB.test.after_pending and "After" or "Before"
	if AB.test.state == "await_isolate" then return (phase and phase.label or outside) .. ": reloading the UI so it starts from a fresh Lua state" end
	if AB.test.state == "settle" then
		return string.format("%s: letting add-ons settle after the reload, %d / %d s", phase and phase.label or outside, math.floor((now - AB.test.state_at) / 1000), TIMING.isolate_settle / 1000)
	end
	if AB.test.state == "returning" then
		local how = (AB.test.return_token and UI.On("auto_travel")) and "Auto travel back to " or "Travel back to "
		local try = (AB.test.return_try or 1) > 1 and string.format(" (retry %d of %d)", AB.test.return_try - 1, HOME.retries) or ""
		return AB.test.travel_owner.label .. ": loading screen measured. " .. how .. HOME.Name() .. try .. "."
	end
	if AB.test.state == "after_return" then return AB.test.travel_owner.label .. ": back in " .. HOME.Name() .. ", settling" end
	if AB.test.state == "fill" and AB.test.fill_done_at then return phase.label .. ": letting the fill settle" end
	if AB.test.state == "fill" and AB.test.hold_pool then return string.format("%s: filling the add-on pool to %s MB, now %s MB", phase.label, Fmt(AB.test.hold_pool), Fmt(PoolMB() or 0)) end
	if AB.test.state == "fill" then return string.format("%s: holding %s of %s MB", phase.label, Fmt(#AB.test.hold * ChunkKB() / 1024), Fmt(AB.test.hold_mb or 0)) end
	if AB.test.state == "await_reload" then return AB.test.phase.label .. " done. Reloading the UI." end
	if AB.test.state == "after_reload" then return AB.test.phase.label .. ": UI reloaded, reading memory" end
	if AB.test.state == "await_travel" and AB.test.auto_dest then
		local try = (AB.test.auto_try or 1) > 1 and string.format(" (retry %d of %d)", AB.test.auto_try - 1, TIMING.auto_retries) or ""
		return AB.test.travel_owner.label .. " done. Auto travel to " .. AB.test.auto_dest.text .. try .. "."
	end
	if AB.test.state == "await_travel" and AB.test.auto_token then return AB.test.travel_owner.label .. " done. The travel did not start, trying again." end
	if AB.test.state == "await_travel" then return AB.test.travel_owner.label .. " done. " .. TRAVEL_TEXT end
	if AB.test.state == "after_travel" then return AB.test.travel_owner.label .. ": loading screen done, reading memory" end
	return phase.label .. ": measuring " .. Tint(string.format("%d / %d s", math.floor((now - AB.test.state_at) / 1000), AB.test.seconds), BAD)
end

local function StatusText(now)
	return UI.StepText() .. StatusBody(now)
end

function UI.RefreshStatus()
	if not AB.test then return end
	local text = StatusText(GetGameTimeMilliseconds()) .. ". " .. FocusText()
	UI.SetStatusLine(text)
	if UI.IsShown() and AB.status then UI.SetWindowStatus(text) end
end

local function OnFrame()
	if not AB.test then return end
	GUARD.Frame()
	if IsUnitInCombat("player") then
		AB.test.note = "Stopped: combat started."
		return Finish(true)
	end
	local now = GetGameTimeMilliseconds()
	local frame_ms = GetFrameDeltaTimeMilliseconds()
	local phase = AB.test.phase
	UI.TrackPool(now)
	if not WATCHED_ELSEWHERE[AB.test.state] and UI.AtLimit() then return UI.LimitAnywhere(now) end
	if AB.test.state == "before" then
		Record(AB.test.before, now)
		if now >= AB.test.next_sample then Sample(AB.test.before) AB.test.next_sample = now + 1000 end
		if now - AB.test.state_at >= TIMING.before then
			EndSample(AB.test.before)
			AB.test.before_values = Finalize(AB.test.before, { alc = GUARD.HeldState(), workload = "none", timer = "done" })
			if AB.test.before_travel then
				for key, value in pairs(AB.test.before_travel) do AB.test.before_values[key] = value end
				AB.test.before_travel, AB.test.before_pending = nil, nil
				StartPhase(1)
				if not AB.test then return end
			else
				AB.test.before_phase = { label = "Before" }
				AskTravel(AB.test.before_phase, AB.test.before_values, now)
			end
		end
	elseif AB.test.state == "after" then
		Record(AB.test.after, now)
		if now >= AB.test.next_sample then Sample(AB.test.after) AB.test.next_sample = now + 1000 end
		if now - AB.test.state_at >= TIMING.before then
			EndSample(AB.test.after)
			AB.test.after_values = Finalize(AB.test.after, { alc = GUARD.HeldState(), workload = "none", timer = "done", after = true })
			if AB.test.after_travel then
				for key, value in pairs(AB.test.after_travel) do AB.test.after_values[key] = value end
				AB.test.after_travel, AB.test.after_pending = nil, nil
				return Finish(false)
			end
			AB.test.after_phase = AB.test.after_phase or { label = "After" }
			AskTravel(AB.test.after_phase, AB.test.after_values, now)
		end
	elseif AB.test.state == "settle" then
		local ready = now - AB.test.state_at >= TIMING.isolate_settle
		if ready and AB.test.before_pending then
			AB.test.state, AB.test.state_at, AB.test.next_sample = "before", now, now
			AB.test.before = NewStats("Before")
			AB.test.before.lua_start, AB.test.before.pool_start = LuaMB(), PoolMB()
		elseif ready and AB.test.after_pending and not AB.test.after_travel then
			AB.AskTravel(AB.test.after_phase, {}, now)
		elseif ready and AB.test.after_pending then
			AB.test.state, AB.test.state_at, AB.test.next_sample = "after", now, now
			AB.test.after = NewStats("After")
			AB.test.after.lua_start, AB.test.after.pool_start = LuaMB(), PoolMB()
		elseif ready then
			AB.test.state, AB.test.state_at = AB.test.target and "fill" or "measure", now
			if AB.test.state == "measure" then BeginMeasure(phase, now, Alc()) end
		end
	elseif AB.test.state == "fill" then
		if UI.PastLine() then return UI.StopAtLimit(phase, now) end
		if AB.test.fill_done_at then
			if now - AB.test.fill_done_at >= TIMING.fill_settle then BeginMeasure(phase, now, Alc()) end
		else
			FillHoldStep(phase, now)
		end
	elseif AB.test.state == "measure" then
		if UI.AtLimit() then return UI.StopAtLimit(phase, now, UI.LimitWhy()) end
		local stats = phase.stats
		Record(stats, now)
		if AB.test.isolated and AB.test.kind ~= "run" and not phase.pure and not phase.forced and now - AB.test.state_at >= math.min(TIMING.force_at, AB.test.seconds * 500) then
			phase.forced = true
			phase.forced_at = now
			local alc = Alc()
			if phase.cleaner then
				local name = AB.CleanerName(phase.cleaner)
				local ok, freed, cleaned = AB.RunCleaner(phase.cleaner)
				local at = math.floor((now - stats.started) / 100 + 0.5) / 10
				if ok or cleaned then stats.other_runs = (stats.other_runs or 0) + 1 end
				if not ok then
					PhaseNote(phase, cleaned and (name .. "'s own code stopped with an error after it had cleaned (the cleanup is counted)")
						or (name .. "'s own cleanup stopped with an error before it cleaned"))
					stats.other_error = true
				end
				local forced
				if not cleaned and AB.test.force_cleaners then
					stats.other_own_why = not ok and "its cleanup stopped with an error" or (phase.cleaner == "mgc" and "under its own limit" or "its cleanup freed nothing")
					freed, cleaned = AB.ForceClean()
					forced = cleaned
					if forced then stats.other_forced = (stats.other_forced or 0) + 1 end
				end
				stats.last_count = collectgarbage("count")
				if cleaned then stats.other_cleanups, stats.other_freed = (stats.other_cleanups or 0) + 1, (stats.other_freed or 0) + freed end
				stats.events[#stats.events + 1] = { at = at, cleaner = phase.cleaner, freed = math.floor(freed * 100 + 0.5) / 100,
					idle = not cleaned or nil, forced = forced or nil }
			elseif alc and type(alc.run_manual_cleanup) == "function" then
				GUARD.forcing = true
				local ok = pcall(alc.run_manual_cleanup, false, nil, true)
				GUARD.forcing = false
				if not ok then PhaseNote(phase, "ALC's cleanup call failed") end
			else
				PhaseNote(phase, "this ALC version has no cleanup call the benchmark can use")
			end
		end
		if phase.forced_at then AB.OwnCleanerStep(phase, now) end
		if AB.test.player then PLAYER.Step(phase, now) end
		local hold_until = AB.test.hold_s and math.min(AB.test.hold_s, AB.test.seconds) or math.max(AB.test.seconds - TIMING.fill_release_before_s, 0)
		if #AB.test.hold > 0 and now - AB.test.state_at >= hold_until * 1000 then
			AB.test.hold = {}
			phase.held_until = math.floor((now - AB.test.state_at) / 1000 + 0.5)
		end
		if PhaseChurn(phase) > 0 then
			local owed = (AB.test.garbage_owed or 0) + PhaseChurn(phase) * Slowed(phase) * frame_ms / 1000
			AB.test.garbage_owed = owed - MakeGarbage(math.min(owed, FILL_MB_PER_FRAME))
		end
		if now >= AB.test.next_sample then
			Sample(stats)
			AB.test.next_sample = now + 1000
			if not LibAPH.RegisterCleanupListener then
				local alc = Alc()
				local freed = alc and (alc.session_mb_freed or 0) - (phase.freed_before or 0) or 0
				stats.freed_lua = freed
				stats.freed_pool = alc and (alc.session_pool_mb_freed or 0) - (phase.pool_freed_before or 0) or 0
				if freed > 0.001 and stats.cleanups == 0 then stats.cleanups = 1 end
			end
		end
		if now - AB.test.state_at >= AB.test.seconds * 1000 then
			PLAYER.Stop(phase)
			AB.test.hold = {}
			EndSample(stats)
			if phase.travel then
				AskTravel(phase, Finalize(stats, PhaseExtra(phase)), now)
			elseif phase.reload then
				AskReload(phase, Finalize(stats, PhaseExtra(phase)), now)
			else
				phase.values = Finalize(stats, PhaseExtra(phase))
				StartPhase(AB.test.index + 1)
				if not AB.test then return end
			end
		end
	elseif AB.test.state == "after_reload" then
		if now - AB.test.state_at >= TIMING.travel_settle then
			local values = phase.measured
			values.lua_post_reload, values.pool_post_reload = LuaMB(), PoolMB()
			phase.values, phase.measured = values, nil
			StartPhase(AB.test.index + 1)
			if not AB.test then return end
		end
	elseif AB.test.state == "after_travel" then
		if now - AB.test.state_at >= TIMING.travel_settle then
			local owner = AB.test.travel_owner
			local travel = owner.travel_values
			travel.lua_post_travel, travel.pool_post_travel = LuaMB(), PoolMB()
			local values = owner.measured
			for key, value in pairs(travel) do values[key] = value end
			if HOME.AtHome() then
				HOME.Continue(owner, values)
				if not AB.test then return end
			else
				AB.test.state, AB.test.state_at, AB.test.return_values, AB.test.home_from = "returning", now, values, now
				HOME.Jump(1)
			end
		end
	elseif AB.test.state == "after_return" then
		if now - AB.test.state_at >= TIMING.travel_settle then
			HOME.Continue(AB.test.travel_owner, AB.test.return_values)
			if not AB.test then return end
		end
	end
	if AB.test and now >= (AB.test.next_draw or 0) then
		AB.test.next_draw = now + 1000
		UI.KeepPartial()
		local text = StatusText(now) .. ". " .. FocusText()
		UI.SetStatusLine(text)
		if UI.IsShown() then
			local before = collectgarbage("count")
			UI.LiveSet(LiveColumns(), AB.test.compare, text)
			local made = collectgarbage("count") - before
			local state = AB.test.state
			local stats = (state == "measure" and AB.test.phase and AB.test.phase.stats) or (state == "before" and AB.test.before) or (state == "after" and AB.test.after)
			if stats then
				stats.window_s = (stats.window_s or 0) + 1
				if made > 0 then stats.window_kb = (stats.window_kb or 0) + made end
			end
		end
	end
end

function UI.StopAtLimit(phase, now, why)
	local used, cap = PoolMB(), PoolCapacityMB()
	PLAYER.Stop(phase)
	if not phase.stats then BeginMeasure(phase, now, Alc()) end
	local measuring = AB.test.state == "measure" or AB.test.state == "fill"
	local seconds = (now - (measuring and AB.test.state_at or phase.stats.started)) / 1000
	local warned = AB.test.low_warning
	if warned and warned.where ~= phase.label then warned = nil end
	why = why or string.format("went past %s MB", Fmt(UI.LineMB() or 0))
	Sample(phase.stats)
	local values = Finalize(phase.stats, PhaseExtra(phase))
	values.limit_s, values.limit_pool, values.limit_cap, values.limit_why = seconds, used, cap, why
	values.low_memory = warned and warned.text or string.format("Add-on pool at %s of %s MB", Fmt(used), Fmt(cap))
	phase.values = values
	AB.test.hold = {}
	if AB.test.isolated then
		StartPhase(AB.test.index + 1, true)
		return
	end
	AB.test.note = "Ended at the add-on memory limit."
	Finish(true)
	LibAPH.StepCleanup(1)
end

local function FailValues(values, warning, seconds, used, cap)
	values.low_memory = warning
	values.limit_s, values.limit_pool, values.limit_cap = seconds, used, cap
	return values
end

function UI.OnLowMemory(used, cap)
	local test = AB.test
	local now = GetGameTimeMilliseconds()
	local phase = test.phase
	local measuring = phase ~= nil and (test.state == "fill" or test.state == "measure")
	local seconds = measuring and math.floor((now - test.state_at) / 1000 + 0.5) or nil
	local warning = string.format("Low Add-On memory: %g MB/%g MB", used, cap)
	local where = phase and phase.label or ((test.state == "after" or test.after_pending) and "After" or "Before")
	local protect = AB.saved.memory_limit_stop ~= false
	test.low_warning = { text = warning, where = where, s = seconds, used = used, cap = cap, protect = protect, count = (test.low_warning and test.low_warning.count or 0) + 1 }
	local stats = phase and test.state == "measure" and phase.stats
	if stats then
		stats.warnings = (stats.warnings or 0) + 1
		stats.events[#stats.events + 1] = { at = math.floor((now - stats.started) / 100 + 0.5) / 10, warning = warning }
	end
	if phase and phase.mode and phase.mode ~= "vanilla" and test.state ~= "measure" then
		PhaseNote(phase, "the game warned of low add-on memory before the phase measured, so ALC's own low-memory cleanup was held")
	end
	UI.SaveNow(true)
end

function UI.LimitAnywhere(now)
	local t = AB.test
	if t.phase and t.index >= 1 and t.index <= #t.phases then return UI.StopAtLimit(t.phase, now, UI.LimitWhy()) end
	t.limit_retries = (t.limit_retries or 0) + 1
	if t.limit_retries > TIMING.limit_retries then
		t.note = "Stopped: the add-on pool stayed near its limit even after reloading."
		return Finish(true)
	end
	UI.SaveNow()
	UI.Isolate(true)
end

function UI.TakeAlcReload()
	local t = AB.test
	if not UI.AlcReloading() then return end
	local phase, now = t.phase, GetGameTimeMilliseconds()
	PLAYER.Stop(phase)
	if not phase.stats then BeginMeasure(phase, now, Alc()) end
	local stats, pool = phase.stats, PoolMB()
	stats.events[#stats.events + 1] = { at = math.floor((now - stats.started) / 100 + 0.5) / 10, alc_reload = math.floor((pool or 0) * 100 + 0.5) / 100 }
	Sample(stats)
	local values = Finalize(stats, PhaseExtra(phase))
	values.alc_reload_s, values.alc_reload_pool = (now - t.state_at) / 1000, pool
	phase.values = values
	t.hold = {}
	StartPhase(t.index + 1, "hook")
end

function UI.CanContinue()
	local cut = AB.saved.cut
	if type(cut) ~= "table" then return false end
	if GetTimeStamp() - (cut.at or 0) > TIMING.continue_max then
		AB.saved.cut = nil
		return false
	end
	return true
end

function UI.Continue()
	if AB.test or not UI.CanContinue() then return end
	local cut = AB.saved.cut
	local state = cut.state
	if state.home then
		local here = HOME.Here()
		if here.zone ~= state.home.zone or here.house ~= state.home.house then
			return Say(string.format("Travel back to %s first: every phase of this test was measured there.", zo_strformat("<<1>>", GetZoneNameById(state.home.zone) or "")))
		end
	end
	AB.saved.cut = nil
	local history, failed_column = History(), nil
	for index = #history, 1, -1 do
		if history[index].id == cut.record_id then
			for _, column in ipairs(cut.skip and history[index].columns or {}) do
				if column.label == cut.skip.label then failed_column = column end
			end
			table.remove(history, index)
		end
	end
	local keep = { label = true, mode = true, pure = true, cleaner = true, travel = true, reload = true }
	if failed_column then
		local w = cut.skip.warning
		local failed = state.phases[state.index]
		for key in pairs(failed) do
			if not keep[key] then failed[key] = nil end
		end
		local values = {}
		for key, value in pairs(failed_column) do values[key] = value end
		values.timer = nil
		failed.values = FailValues(values, w.text, w.s or values.seconds or 0, w.used, w.cap)
		state.index = state.index + 1
	end
	local phase = state.phases[state.index]
	for key in pairs(phase) do
		if not keep[key] then phase[key] = nil end
	end
	local alc = Alc()
	if alc and alc.settings then AB.HoldAlcReloads(alc) end
	if state.clock then state.clock.gap_s = (state.clock.gap_s or 0) + math.max(GetTimeStamp() - (cut.cut_at or cut.at or GetTimeStamp()), 0) end
	state.at, state.isolate, state.iso_from_ms, state.iso_from_ts = GetTimeStamp(), true, nil, nil
	state.tainted = "it was continued from the crash copy, which can be edited before it is continued"
	AB.saved.resume = state
	AB.Resume()
	if AB.test then UI.Hide() end
	if AB.test and failed_column then
		AB.test.continued = string.format("Continued after the add-ons ran out of memory during %s: it was kept as failed and the test carried on from %s.", cut.skip.label, tostring(cut.where))
	elseif AB.test then
		AB.test.continued = string.format("Continued after being cut off during %s: that phase was run again from the start.", tostring(cut.where))
	end
end

AB.Resume = function()
	local r = AB.saved.resume
	AB.saved.resume = nil
	if not r then
		if UI.RecoverPartial() then ShowSaved() end
		return
	end
	if not r.phases or GetTimeStamp() - (r.at or 0) > TIMING.resume_age_sec or not (r.isolate or (r.phases[r.index] and r.phases[r.index].measured)) then
		Restore(r.restore)
		LibAPH.ReleaseGameSettings(r.held)
		UI.RecoverPartial()
		return
	end
	local tainted = r.tainted
	if not tainted and AB.ProgressStatus(r) ~= "sealed" then tainted = "its progress saved for a reload was changed before the test carried on" end
	local now = GetGameTimeMilliseconds()
	local measured = not r.isolate and r.phases[r.index].measured
	if measured then
		local load_ms = measured.reload_ms_at and now - measured.reload_ms_at
		if not load_ms or load_ms <= 0 or load_ms > TIMING.max_load then
			load_ms = measured.reload_ts_at and (GetTimeStamp() - measured.reload_ts_at) * 1000 or nil
		end
		measured.reload_s = load_ms and load_ms / 1000 or nil
		measured.reload_ms_at, measured.reload_ts_at = nil, nil
	end
	if r.isolate and r.clock then
		local iso_ms = r.iso_from_ms and now - r.iso_from_ms
		if not iso_ms or iso_ms <= 0 or iso_ms > TIMING.max_load then
			iso_ms = r.iso_from_ts and (GetTimeStamp() - r.iso_from_ts) * 1000 or nil
		end
		if iso_ms then r.clock.iso_s, r.clock.iso_n = r.clock.iso_s + iso_ms / 1000, r.clock.iso_n + 1 end
	end
	AB.test = {
		kind = r.kind, seconds = r.seconds, churn = r.churn, real = r.real, reload = r.reload, phases = r.phases, index = r.index,
		before_values = r.before_values, metric_name = r.metric_name, target = r.target,
		restore = r.restore, visited = r.visited or {}, addons = r.addons,
		held = r.held, held_cleaners = r.held_cleaners, cleaner_timers = r.cleaner_timers, force_cleaners = r.force_cleaners, isolated = r.isolated, home = r.home, fixed_dest = r.fixed_dest, fresh = true, continued = r.continued, vanilla_garbage = r.vanilla_garbage, clock = r.clock, fps = r.fps,
		before_pending = r.before_pending, before_travel = r.before_travel, fair_before = r.fair_before, before_phase = r.before_pending and { label = "Before" } or nil,
		after_pending = r.after_pending, after_travel = r.after_travel, fair_after = r.fair_after, after_phase = r.after_pending and { label = "After" } or nil,
		tainted = tainted, low_warning = r.low_warning, own_cleaning = r.own_cleaning, player = r.player, limit_retries = r.limit_retries,
		hold_mb = r.hold_mb, hold_pool = r.hold_pool, hold_s = r.hold_s,
	}
	UI.crash_copy:Reset()
	AB.test.phase = AB.test.phases[AB.test.index]
	AB.test.compare = Compare()
	LibAPH.ReholdGameSettings(AB.test.held)
	AB.test.state, AB.test.state_at, AB.test.next_sample = r.isolate and "settle" or "after_reload", now, now
	if r.isolate then AB.test.fresh, AB.test.hold = nil, {} end
	if LibAPH.RegisterCleanupListener then LibAPH.RegisterCleanupListener(NAME, OnCleanup) end
	GUARD.Start()
	EVENT_MANAGER:RegisterForUpdate(NAME, 0, OnFrame)
	UI.Set(LiveColumns(), AB.test.compare, StatusText(now) .. ". " .. FocusText())
	UI.SetStatusLine(StatusText(now) .. ". " .. FocusText())
end

local function Begin(kind, seconds, churn, phases)
	ChunkKB()
	AB.saved.cut, AB.saved.partial = nil, nil
	UI.crash_copy:Reset()
	if AB.test.real then churn = 0 end
	AB.test.vanilla_garbage = (IsConsoleUI() and not AB.test.real) or nil
	AB.test.kind, AB.test.seconds, AB.test.churn, AB.test.phases = kind, seconds, churn, phases
	AB.test.own_cleaning = true
	AB.test.player = AB.saved.simulate_player == true or nil
	AB.test.visited = { [LibAPH.GetCurrentPlace().zone] = true }
	AB.test.clock = { start_ts = GetTimeStamp(), settle_s = AB.test.isolated and TIMING.isolate_settle / 1000 or nil, iso_s = 0, iso_n = 0, home_s = 0, home_n = 0 }
	if UI.On("same_place") then
		if HOME.Owned() then
			AB.test.home = HOME.Here()
		else
			AB.test.note = "Same place was on, but the test did not start in a house you own, so each loading screen left you somewhere new."
		end
	end
	AB.test.addons = LibAPH.CountRunningAddOns()
	AB.test.held = LibAPH.HoldGameSettings()
	if not IsConsoleUI() then AB.test.fps = LibAPH.GetFpsCap() or "uncapped" end
	AB.test.held_cleaners, AB.test.cleaner_timers = AB.HeldCleaners(), AB.CleanerTimers()
	if AB.test.isolated then
		AB.test.before_pending, AB.test.index, AB.test.fair_before = true, 0, true
		AB.test.before_phase = { label = "Before" }
	else
		AB.test.state, AB.test.state_at, AB.test.next_sample = "before", GetGameTimeMilliseconds(), GetGameTimeMilliseconds()
		AB.test.before = NewStats("Before")
		AB.test.before.lua_start, AB.test.before.pool_start = LuaMB(), PoolMB()
	end
	if LibAPH.RegisterCleanupListener then LibAPH.RegisterCleanupListener(NAME, OnCleanup) end
	GUARD.Start()
	EVENT_MANAGER:RegisterForUpdate(NAME, 0, OnFrame)
	AB.test.compare = Compare()
	UI.live_index, UI.live_state = nil, nil
	UI.Hide()
	UI.Set(LiveColumns(), AB.test.compare, AB.test.before_pending and "Before: loading screen first" or "Before: measuring")
	UI.SetStatusLine(UI.StepText() .. (AB.test.before_pending and "Before: loading screen first" or "Before: measuring"))
	if AB.test.before_pending then AskTravel(AB.test.before_phase, {}, GetGameTimeMilliseconds()) end
end

local function AllPhases(reload, alc_only, with_alc, cleaners)
	local methods = {}
	if not alc_only then methods[#methods + 1] = { "A: Vanilla", "vanilla", true } end
	if with_alc then
		for _, m in ipairs({ { "B: Automatic", "automatic" }, { "C: Background", "background" }, { "D: Aggressive", "aggressive" }, { "E: Deep Clean", "deep" } }) do
			methods[#methods + 1] = m
		end
	end
	for _, cleaner in ipairs(cleaners or {}) do
		methods[#methods + 1] = { cleaner.letter .. ": " .. cleaner.name, "vanilla", nil, cleaner.key }
	end
	local phases = {}
	for _, m in ipairs(methods) do
		phases[#phases + 1] = { label = m[1], mode = m[2], pure = m[3], cleaner = m[4], travel = true }
		phases[#phases + 1] = { label = m[1] .. " + no travel", mode = m[2], pure = m[3], cleaner = m[4] }
		if reload then phases[#phases + 1] = { label = m[1] .. " + reload", mode = m[2], pure = m[3], cleaner = m[4], reload = true } end
	end
	return phases
end

local function CleanersSay(alc_ready, cleaners)
	local taking, left = {}, {}
	if alc_ready then taking[#taking + 1] = "ALC" else left[#left + 1] = "ALC (" .. tostring(UI.AlcBlocked()) .. ")" end
	local using = {}
	for _, cleaner in ipairs(cleaners) do
		using[cleaner.key] = true
		taking[#taking + 1] = cleaner.name
	end
	for _, cleaner in ipairs(AB.CLEANERS) do
		local why = AB.CleanerBlocked(cleaner.key)
		if not using[cleaner.key] and why ~= "PC only" then left[#left + 1] = cleaner.name .. " (" .. tostring(why) .. ")" end
	end
	local text = "ALL TEST with Vanilla and " .. table.concat(taking, ", ") .. "."
	if #left > 0 then text = text .. " Left out: " .. table.concat(left, ", ") .. "." end
	return text
end

local function StartAB(seconds, churn, opts, alc_only)
	if AB.test then return Say("A test is already running; /alcbench stop ends it.") end
	if IsUnitInCombat("player") then return Say("Leave combat first.") end
	local alc = Alc()
	local alc_ready = alc and alc.settings and alc.settings.is_enabled
	local cleaners = alc_only and {} or AB.UsableCleaners()
	if alc_only or #cleaners == 0 then
		if not (alc and alc.settings) then
			return Say(alc_only and "Auto Lua Memory Cleaner is not loaded, so there is nothing to compare. /alcbench vanilla measures without it."
				or "No Lua cleaner is on, so there is nothing to compare: turn on Auto Lua Memory Cleaner, Memory Garbage Collector or Shissu's LUA Memory. /alcbench vanilla measures without them.")
		end
		if not alc.settings.is_enabled then return Say("Turn on Auto Lua Cleanup in ALC's settings first; with it off ALC never checks memory.") end
	end
	local hold_mb, hold_pool, hold_s = AB.FillHold()
	AB.test = { metric_name = hold_pool and "pool held" or "held", target = hold_pool or hold_mb, hold_mb = hold_mb, hold_pool = hold_pool, hold_s = hold_s }
	if alc and alc.settings then
		AB.test.restore = { mode = alc.settings.cleanup_mode, pool_travel = alc.settings.auto_clear_pool_on_teleport, afk = alc.settings.afk_reload }
		AB.HoldAlcReloads(alc)
	end
	AB.test.real, AB.test.reload = opts.real, opts.reload
	if AB.test.real then AB.test.target = nil end
	AB.test.isolated = true
	AB.test.force_cleaners = (#cleaners > 0 and AB.ForcingCleaners()) or nil
	if not alc_only then Say(CleanersSay(alc_ready, cleaners)) end
	Begin(alc_only and "alc_only" or "ab", seconds, churn, AllPhases(opts.reload, alc_only, alc_ready, cleaners))
end

function UI.AlcBlocked()
	local alc = Alc()
	if not (alc and alc.settings) then return "turn ALC on first" end
	if not alc.settings.is_enabled then return "turn on Auto Lua Cleanup first" end
	return nil
end

function UI.AllBlocked()
	local alc_reason = UI.AlcBlocked()
	if not alc_reason or #AB.UsableCleaners() > 0 then return nil end
	return alc_reason
end

function UI.VanillaBlocked()
	local alc = Alc()
	return alc and alc.settings and alc.settings.is_enabled and true or false
end

local function StartRun(seconds, churn, opts)
	if AB.test then return Say("A test is already running; /alcbench stop ends it.") end
	if IsUnitInCombat("player") then return Say("Leave combat first.") end
	if UI.VanillaBlocked() then
		return Say("Turn ALC off first: switch off Auto Lua Cleanup in ALC's settings, or disable Auto Lua Memory Cleaner in the add-on list. The VANILLA ONLY TEST measures the game on its own.")
	end
	local alc = Alc()
	local restore = alc and alc.settings and { mode = alc.settings.cleanup_mode, pool_travel = alc.settings.auto_clear_pool_on_teleport, afk = alc.settings.afk_reload } or nil
	if restore then AB.HoldAlcReloads(alc) end
	local hold_mb, hold_pool, hold_s = AB.FillHold()
	AB.test = { metric_name = hold_pool and "pool held" or "held", target = hold_pool or hold_mb, hold_mb = hold_mb, hold_pool = hold_pool, hold_s = hold_s, restore = restore, real = opts.real, reload = opts.reload }
	if AB.test.real then AB.test.target = nil end
	local method = MethodLabel()
	local phases
	if GAME_ONLY[method] then
		phases = { { label = method .. " + travel", travel = true }, { label = method .. " + no travel" } }
	else
		phases = { { label = method, travel = true } }
	end
	if opts.reload then phases[#phases + 1] = { label = method .. " + reload", reload = true } end
	AB.test.isolated = true
	Begin("run", seconds, churn, phases)
end

AB.fill_left = 0
local function FillStep()
	if not AB.CpuRoom() then return end
	local mb = math.min(FILL_MB_PER_FRAME, AB.fill_left)
	MakeGarbage(mb)
	AB.fill_left = AB.fill_left - mb
	if AB.fill_left <= 0 then
		EVENT_MANAGER:UnregisterForUpdate(NAME .. "_Fill")
		local pool = PoolMB()
		Say(string.format("Made the garbage. Lua %s MB%s.", Fmt(LuaMB()), pool and (", pool " .. Fmt(pool) .. " MB") or ""))
		if UI.IsShown() and not AB.test then ShowSaved() end
	end
end
AB.StartAB, AB.StartRun, AB.FillStep = StartAB, StartRun, FillStep
