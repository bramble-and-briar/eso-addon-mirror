--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

local AB = ALCBenchmark
local UI, LiveColumns, PoolMB, PoolLimitMB, TIMING, NAME = AB.UI, AB.LiveColumns, AB.PoolMB, AB.PoolLimitMB, AB.TIMING, AB.NAME
local Restore, Fmt, History, HISTORY_MAX, Say = AB.Restore, AB.Fmt, AB.History, AB.HISTORY_MAX, AB.Say

local copy = LibAPH.CreateCrashCopy({
	addonName = NAME,
	key = "partial",
	store = function() return AB.saved end,
	active = function() return AB.test ~= nil end,
	expectedReload = function() return AB.test ~= nil and (AB.test.state == "await_isolate" or AB.test.state == "await_reload" or UI.AlcReloading()) end,
	saveShare = TIMING.save_share,
	saveEveryMs = TIMING.save_every,
	onCause = function() UI.KeepPartial() end,
})
UI.crash_copy = copy

function UI.KeepPartial()
	local test = AB.test
	local partial = copy:Get()
	local columns = LiveColumns()
	if not partial or UI.partial_owner ~= test or test.partial_index ~= test.index or test.partial_state ~= test.state then
		test.partial_index, test.partial_state = test.index, test.state
		local where = test.phase and test.phase.label or ((test.state == "after" or test.after_pending or (test.index or 0) > #test.phases) and "After" or "Before")
		local can_rerun = test.isolated and test.index and test.index >= 1 and test.index <= #test.phases and UI.ResumeSnapshot
		UI.partial_owner = test
		partial = { where = where, restore = test.restore, held = test.held,
			state = can_rerun and UI.ResumeSnapshot() or nil, record = UI.MakeRecord(columns, true) }
		AB.saved.partial = partial
	end
	partial.low_warning = test.low_warning
	copy:Update()
end

function UI.RecoverPartial()
	local kept = copy:Take()
	if not kept or type(kept.record) ~= "table" then return false end
	Restore(kept.restore)
	LibAPH.ReleaseGameSettings(kept.held)
	local record = kept.record
	for _, column in ipairs(record.columns or {}) do
		if column.series and UI.PackSeries then column.packed, column.series = UI.PackSeries(column.series), nil end
	end
	local same_phase = kept.low_warning ~= nil and kept.low_warning.where == kept.where
	local reason = LibAPH.GetCrashReason(kept, { lowMemory = same_phase, saveShare = TIMING.save_share })
	local why
	local short, warned = reason.short, nil
	if reason.cause == "logout" then
		why = "you logged out"
	elseif reason.cause == "quit" then
		why = "the game was closed"
	elseif reason.cause == "reload" then
		why = "a /reloadui the test did not start"
	elseif reason.cause == "out_of_memory" then
		warned = kept.low_warning
		why = string.format("the game warned \"%s\"%s, then the test ended with no logout, quit or reload, so the add-ons most likely ran out of memory and were disabled", warned.text, warned.s and string.format(" after %d s", warned.s) or "")
		record.failed = string.format("Failed: the add-ons most likely ran out of memory during %s (the game warned \"%s\"%s first)%s.", tostring(kept.where), warned.text, warned.s and string.format(" after %d s", warned.s) or "", warned.protect and "" or "; Low memory protection was off")
	elseif reason.cause == "likely_out_of_memory" then
		why = string.format("it ended without warning with the add-on pool at %s of %s MB, so most likely it ran out of add-on memory", Fmt(kept.pool), Fmt(kept.cap))
	else
		why = "it ended without warning (most likely a disconnect, a kick from the server or a crash)"
	end
	local cut
	for _, column in ipairs(record.columns or {}) do
		if column.label == kept.where then cut = column end
	end
	if not cut then
		for _, column in ipairs(record.columns or {}) do
			if (column.frames or 0) > 0 then cut = column end
		end
	end
	if cut then
		cut.cut_reason = short
		if warned then
			cut.low_memory = warned.text
			cut.limit_s, cut.limit_pool, cut.limit_cap = warned.s or cut.seconds or 0, warned.used, warned.cap
		end
	end
	record.cut_reason = short
	record.recovered = string.format("Cut off during %s: %s. Everything up to the last second before that is kept.", tostring(kept.where), why)
	record.stopped = true
	record.id = (AB.saved.next_id or 0) + 1
	AB.saved.next_id = record.id
	LibAPH.RoundNumbers(record, 2)
	record.unsealed = "it was recovered from the crash copy"
	local history = History()
	table.insert(history, 1, record)
	while #history > HISTORY_MAX do table.remove(history) end
	if type(kept.state) == "table" then
		AB.saved.cut = { at = GetTimeStamp(), cut_at = kept.at, where = kept.where, state = kept.state, record_id = record.id }
		local state, w = kept.state, record.failed and kept.low_warning
		local phase = w and type(state.phases) == "table" and state.phases[state.index]
		if phase and state.kind ~= "run" and phase.mode == "vanilla" and phase.label == w.where and state.index < #state.phases then
			AB.saved.cut.skip = { label = phase.label, warning = w }
			AB.saved.cut.where = state.phases[state.index + 1].label
		end
		local plan = AB.saved.cut.skip and string.format("to keep %s as failed and carry on from %s", tostring(kept.where), tostring(AB.saved.cut.where)) or string.format("to run %s again and carry on", tostring(kept.where))
		Say(record.recovered .. string.format(" Pick \"Continue the cut-off test\" in the menu within %d minutes %s.", TIMING.continue_max / 60, plan))
	else
		Say(record.recovered)
	end
	return true
end

function UI.SaveNow(rebuild)
	if rebuild and AB.test then AB.test.partial_state = nil end
	UI.KeepPartial()
	copy:SaveNow()
end

local SLOW_DOWN = { { 3, 0.5 }, { 2, 0.3 }, { 1, 0.2 }, { 0.5, 0.1 }, { 0.25, 0.05 } }
local LOOKAHEAD_S, RATE_EVERY_MS, RATE_SAMPLES = 1, 250, 5
local sample_ms, sample_mb = {}, {}

function UI.AlcHandlesLowMemory()
	local phase = AB.test and AB.test.phase
	local alc = AB.Alc()
	return phase ~= nil and phase.mode ~= nil and phase.mode ~= "vanilla" and IsConsoleUI() and alc ~= nil and alc.settings ~= nil and alc.settings.lowmem_reload == true
end

function UI.AlcReloading()
	local t = AB.test
	local alc = AB.Alc()
	return t ~= nil and (t.state == "fill" or t.state == "measure") and UI.AlcHandlesLowMemory() and alc.settings.lowmem_reload_pending == true
end

function UI.LineMB()
	local limit = PoolLimitMB()
	return limit and limit - (UI.AlcHandlesLowMemory() and TIMING.alc_reload_margin or TIMING.limit_margin)
end

function UI.RoomMB()
	if AB.saved.memory_limit_stop == false then return math.huge end
	local line = UI.LineMB()
	local used = line and PoolMB()
	if not used then return math.huge end
	return line - used
end

function UI.TrackPool(now)
	local used = PoolMB()
	local count = #sample_ms
	if not used or (count > 0 and now < sample_ms[count]) then
		for index = count, 1, -1 do sample_ms[index], sample_mb[index] = nil, nil end
		UI.pool_rate = nil
		if not used then return end
		count = 0
	end
	if count > 0 and now - sample_ms[count] < RATE_EVERY_MS then return end
	count = count + 1
	sample_ms[count], sample_mb[count] = now, used
	if count > RATE_SAMPLES then
		table.remove(sample_ms, 1)
		table.remove(sample_mb, 1)
		count = RATE_SAMPLES
	end
	if count < 3 or sample_mb[count] <= sample_mb[count - 1] or sample_mb[count - 1] <= sample_mb[count - 2] then
		UI.pool_rate = 0
		return
	end
	UI.pool_rate = (sample_mb[count] - sample_mb[1]) * 1000 / (sample_ms[count] - sample_ms[1])
end

function UI.ResetPoolTrack()
	for index = #sample_ms, 1, -1 do sample_ms[index], sample_mb[index] = nil, nil end
	UI.pool_rate = nil
end

function UI.PastLine()
	return UI.RoomMB() < 0
end

function UI.HeadingOver()
	if AB.saved.memory_limit_stop == false or not UI.pool_rate or UI.pool_rate <= 0 then return false end
	local limit = PoolLimitMB()
	local used = limit and PoolMB()
	if not used then return false end
	local margin = UI.AlcHandlesLowMemory() and TIMING.alc_heading_margin or TIMING.heading_margin
	return used + UI.pool_rate * LOOKAHEAD_S >= limit - margin
end

function UI.FillFitsMB(want)
	if AB.saved.memory_limit_stop == false then return want end
	local limit = PoolLimitMB()
	local used = limit and PoolMB()
	if not used then return want end
	return math.min(want, limit - TIMING.fill_cap_margin_mb - used)
end

function UI.AtLimit()
	return UI.RoomMB() < 0 or UI.HeadingOver()
end

function UI.LimitWhy()
	if UI.RoomMB() >= 0 and UI.HeadingOver() then
		return string.format("was heading for the limit at %s MB/s", Fmt(UI.pool_rate, 1))
	end
	return nil
end

function UI.GarbageShare()
	local room, share = UI.RoomMB(), 1
	for _, step in ipairs(SLOW_DOWN) do
		if room <= step[1] then share = step[2] end
	end
	return share
end

ZO_PreHook("ReloadUI", function()
	local ab = rawget(_G, "ALCBenchmark")
	if ab and ab.UI.TakeAlcReload then ab.UI.TakeAlcReload() end
end)

if LibAPH.RegisterLowMemoryCallback then
	LibAPH.RegisterLowMemoryCallback(NAME, function(used, cap)
		if AB.test then UI.OnLowMemory(used, cap) end
	end)
end
