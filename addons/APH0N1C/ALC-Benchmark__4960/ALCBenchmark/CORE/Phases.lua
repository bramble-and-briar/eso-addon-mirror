--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

local AB = ALCBenchmark
local GUARD, NAME, StopTravelWatch, Restore, Finalize = AB.GUARD, AB.NAME, AB.StopTravelWatch, AB.Restore, AB.Finalize
local PhaseExtra, LiveColumns, UI, History, HISTORY_MAX, view = AB.PhaseExtra, AB.LiveColumns, AB.UI, AB.History, AB.HISTORY_MAX, AB.view
local FirstComparable, ShowSaved, NewStats, LuaMB, PoolMB, Alc = AB.FirstComparable, AB.ShowSaved, AB.NewStats, AB.LuaMB, AB.PoolMB, AB.Alc
local SetAlcMode, Pad, TIMING, AlcState, ChunkKB = AB.SetAlcMode, AB.Pad, AB.TIMING, AB.AlcState, AB.ChunkKB

local SEAL = LibAPH.CreateSeal({ salt = NAME, skip = { "name" }, verify = UI.RecordConsistent })

function UI.SealStatus(record)
	if not SEAL then return "not_sealed" end
	return SEAL.Check(record)
end

function UI.SealMarkers(record, status)
	local markers, invalid = {}, false
	if status == "sealed" or status == "running" then return markers, invalid end
	local account, world = record.seal_account, record.seal_world
	local other_account = status == "other_player" or (status ~= "other_server" and type(account) == "string" and account ~= GetDisplayName())
	local other_world = status == "other_server" or (status ~= "other_player" and type(world) == "string" and world ~= GetWorldName())
	if other_account then
		markers[#markers + 1] = type(world) == "string" and string.format("Test from another account (%s, %s).", tostring(account), world) or string.format("Test from another account (%s).", tostring(account))
	elseif other_world then
		markers[#markers + 1] = string.format("Test from another server (%s).", world)
	end
	if status == "changed" then
		markers[#markers + 1] = "Test was edited, Invalid data."
		invalid = true
	elseif status == "not_sealed" and not (record.recovered or record.unsealed) then
		markers[#markers + 1] = "Test Data Invalid."
		invalid = true
	end
	return markers, invalid
end

function UI.SealInvalid(record)
	if not SEAL or type(record) ~= "table" then return false end
	local _, invalid = UI.SealMarkers(record, UI.SealStatus(record))
	return invalid
end

function UI.SealNote(record)
	local status = UI.SealStatus(record)
	if SEAL and status == "not_sealed" and record.recovered then return "The test was recovered from the crash copy." end
	if SEAL and status == "not_sealed" and record.unsealed then return "Not sealed: " .. record.unsealed .. "." end
	if not SEAL then return nil end
	local markers, invalid = UI.SealMarkers(record, status)
	if #markers == 0 then return nil end
	return table.concat(markers, " "), invalid and AB.BAD or AB.SAME
end

local function Finish(stopped)
	if AB.test and AB.test.phase then AB.PLAYER.Stop(AB.test.phase) end
	GUARD.Stop()
	if AB.saved then AB.saved.resume, AB.saved.partial = nil, nil end
	if AB.test then LibAPH.ReleaseGameSettings(AB.test.held) end
	EVENT_MANAGER:UnregisterForUpdate(NAME)
	StopTravelWatch()
	if AB.test then AB.test.hold = nil end
	if LibAPH.UnregisterCleanupListener then LibAPH.UnregisterCleanupListener(NAME) end
	Restore()
	if not AB.test then return end
	if not AB.test.before_values and AB.test.before then AB.test.before_values = Finalize(AB.test.before, { alc = GUARD.HeldState(), workload = "none", timer = "done" }) end
	if not AB.test.after_values and AB.test.after then AB.test.after_values = Finalize(AB.test.after, { alc = GUARD.HeldState(), workload = "none", timer = "done", after = true }) end
	for index, phase in ipairs(AB.test.phases) do
		if not phase.values and phase.stats and index == AB.test.index then phase.values = Finalize(phase.stats, PhaseExtra(phase)) end
	end
	local columns = {}
	for index, column in ipairs(LiveColumns()) do
		if column.series then column.packed, column.series = UI.PackSeries(column.series), nil end
		columns[index] = column
	end
	local record = UI.MakeRecord(columns, stopped)
	record.id = (AB.saved.next_id or 0) + 1
	AB.saved.next_id = record.id
	if AB.test.tainted or not SEAL then
		LibAPH.RoundNumbers(record, 2)
		record.unsealed = AB.test.tainted or "the add-on could not get its seal"
	else
		SEAL.Seal(record)
	end
	local history = History()
	table.insert(history, 1, record)
	while #history > HISTORY_MAX do table.remove(history) end
	view.shown, view.blank = record, nil
	view.compared = { FirstComparable(record) }
	AB.test = nil
	UI.HideStatusLine()
	ShowSaved()
	UI.Show()
end

local function StartAfter(at_once)
	UI.SaveNow()
	Restore()
	local alc = Alc()
	if alc and alc.settings then AB.HoldAlcReloads(alc) end
	local now = GetGameTimeMilliseconds()
	AB.test.index, AB.test.phase, AB.test.hold = #AB.test.phases + 1, nil, {}
	AB.test.after_phase, AB.test.fair_after = { label = "After" }, true
	if AB.test.isolated then
		AB.test.after_pending = true
		if at_once then return UI.Isolate(true) end
		AB.AskTravel(AB.test.after_phase, {}, now)
		return
	end
	AB.test.state, AB.test.state_at, AB.test.next_sample = "after", now, now
	AB.test.after = NewStats("After")
	AB.test.after.lua_start, AB.test.after.pool_start = LuaMB(), PoolMB()
end

function UI.Isolate(at_once)
	AB.test.state, AB.test.state_at = "await_isolate", GetGameTimeMilliseconds()
	AB.test.iso_from_ms, AB.test.iso_from_ts = GetGameTimeMilliseconds(), GetTimeStamp()
	Pad.Stop()
	AB.SaveResume(true)
	if at_once == "hook" then return end
	if at_once then return ReloadUI("ingame") end
	zo_callLater(function()
		if AB.test and AB.test.state == "await_isolate" then ReloadUI("ingame") end
	end, TIMING.reload_delay)
end

local function StartPhase(index, at_once)
	UI.SaveNow()
	local phase = AB.test.phases[index]
	if not phase then return StartAfter(at_once) end
	AB.test.index, AB.test.phase, AB.test.hold = index, phase, {}
	local alc = Alc()
	if alc and alc.settings and phase.mode then SetAlcMode(alc, "vanilla") end
	if AB.test.isolated and not AB.test.fresh then return UI.Isolate(at_once) end
	AB.test.fresh = nil
	AB.test.state, AB.test.state_at = "settle", GetGameTimeMilliseconds()
end

local function BeginMeasure(phase, now, alc)
	if alc and alc.settings and phase.mode then SetAlcMode(alc, phase.mode) end
	phase.alc_label = AlcState()
	AB.test.state, AB.test.state_at = "measure", now
	AB.test.garbage_owed, AB.test.limit_retries, AB.test.fill_done_at = 0, nil, nil
	UI.ResetPoolTrack()
	phase.stats = NewStats(phase.label)
	phase.stats.lua_start, phase.stats.pool_start = LuaMB(), PoolMB()
	local filled = AB.test.hold and #AB.test.hold * ChunkKB() / 1024 or 0
	phase.held_mb = filled > 0 and filled or nil
	phase.freed_before = alc and alc.session_mb_freed or 0
	phase.pool_freed_before = alc and alc.session_pool_mb_freed or 0
	AB.test.next_sample = now
end

local function OnCleanup(result)
	if not (AB.test and result and result.sources) then return end
	if AB.test.state ~= "measure" then
		if result.sources.AutoLuaMemoryCleaner or result.sources.ALC then AB.test.last_alc_cleanup = GetGameTimeMilliseconds() end
		return
	end
	if not (result.sources.AutoLuaMemoryCleaner or result.sources.ALC) then return end
	AB.test.last_alc_cleanup = GetGameTimeMilliseconds()
	local stats = AB.test.phase.stats
	stats.cleanups = stats.cleanups + 1
	local mode = result.picked or result.method
	local lowmem = result.reason == "lowmem"
	local own = not lowmem and not AB.GUARD.forced_run
	local during = own and AB.GUARD.run_action or nil
	if during then stats["acted_" .. during] = (stats["acted_" .. during] or 0) + 1 end
	local counts = lowmem and stats.lowmem or stats.methods
	if mode then counts[mode] = (counts[mode] or 0) + 1 end
	if own then stats.own_cleanups = (stats.own_cleanups or 0) + 1 end
	stats.events[#stats.events + 1] = {
		at = math.floor((GetGameTimeMilliseconds() - stats.started) / 100 + 0.5) / 10,
		method = mode, freed = math.floor((result.freedLua or 0) * 100 + 0.5) / 100, lowmem = lowmem or nil, own = own or nil, during = during,
		took = result.tookMs and math.floor(result.tookMs / 100 + 0.5) / 10, cpu = result.cpuMs and math.floor(result.cpuMs + 0.5),
	}
	stats.freed_lua = stats.freed_lua + (result.freedLua or 0)
	stats.freed_pool = stats.freed_pool + (result.freedPool or 0)
end

local function Record(stats, now)
	stats.frames = stats.frames + 1
	local count = collectgarbage("count")
	local last = stats.last_count
	if last then
		if count > last then
			stats.made_kb = stats.made_kb + count - last
		elseif count < last and not UI.AlcBusy(now) then
			stats.game_lua_kb = stats.game_lua_kb + last - count
			if now - (stats.last_game_drop or -math.huge) > AB.GAME_RUN_GAP_MS then
				stats.game_cleanups = stats.game_cleanups + 1
				stats.gc_event = { at = math.floor((now - stats.started) / 100 + 0.5) / 10, gc = true, freed = 0 }
				stats.events[#stats.events + 1] = stats.gc_event
			end
			if stats.gc_event then stats.gc_event.freed = stats.gc_event.freed + (last - count) / 1024 end
			stats.last_game_drop = now
		end
	end
	stats.last_count = count
end
AB.Finish, AB.StartPhase, AB.BeginMeasure, AB.OnCleanup, AB.Record = Finish, StartPhase, BeginMeasure, OnCleanup, Record
