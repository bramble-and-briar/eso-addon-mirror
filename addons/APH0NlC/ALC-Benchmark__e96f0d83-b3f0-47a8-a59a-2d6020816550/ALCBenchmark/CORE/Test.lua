--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

local AB = ALCBenchmark
local Finalize, GUARD, PhaseExtra, NAME, UI, Fmt = AB.Finalize, AB.GUARD, AB.PhaseExtra, AB.NAME, AB.UI, AB.Fmt

local live_columns = {}

local function LiveColumns()
	local columns = live_columns
	for index = #columns, 1, -1 do columns[index] = nil end
	if AB.test.before_values then
		columns[1] = AB.test.before_values
	elseif AB.test.before then
		local before = Finalize(AB.test.before, nil, AB.test.before.live or {})
		AB.test.before.live = before
		before.alc, before.workload, before.timer = GUARD.HeldState(), "none", "active"
		columns[1] = before
	else
		AB.test.before_placeholder = AB.test.before_placeholder or { label = "Before" }
		columns[1] = AB.test.before_placeholder
	end
	for index, phase in ipairs(AB.test.phases) do
		if phase.values then
			columns[#columns + 1] = phase.values
		elseif phase.measured then
			columns[#columns + 1] = phase.measured
		elseif phase.stats and index == AB.test.index then
			local live = Finalize(phase.stats, nil, phase.stats.live or {})
			phase.stats.live = live
			PhaseExtra(phase, live)
			live.timer = AB.test.state == "measure" and "active" or nil
			columns[#columns + 1] = live
		else
			phase.placeholder = phase.placeholder or { label = phase.label }
			columns[#columns + 1] = phase.placeholder
		end
	end
	if AB.test.after_values then
		columns[#columns + 1] = AB.test.after_values
	elseif AB.test.after then
		local after = Finalize(AB.test.after, nil, AB.test.after.live or {})
		AB.test.after.live = after
		after.alc, after.workload, after.timer, after.after = GUARD.HeldState(), "none", "active", true
		columns[#columns + 1] = after
	else
		AB.test.after_placeholder = AB.test.after_placeholder or { label = "After", after = true }
		columns[#columns + 1] = AB.test.after_placeholder
	end
	return columns
end

local function Compare()
	local compare, first = {}, {}
	for index, phase in ipairs(AB.test.phases) do
		local kind = phase.travel and "travel" or (phase.reload and "reload" or "stay")
		if first[kind] then
			compare[index + 1] = first[kind]
		else
			first[kind] = index + 1
			compare[index + 1] = index > 1 and 2 or 1
		end
	end
	compare[#AB.test.phases + 2] = 1
	return compare
end

local function StopTravelWatch()
	for _, key in ipairs({ "auto_jump", "home_jump" }) do
		if AB.test and AB.test[key] then
			AB.test[key]:Cancel()
			AB.test[key] = nil
		end
	end
	EVENT_MANAGER:UnregisterForEvent(NAME .. "_Travel", EVENT_PLAYER_DEACTIVATED)
	EVENT_MANAGER:UnregisterForEvent(NAME .. "_Travel", EVENT_PLAYER_ACTIVATED)
end

function UI.MakeRecord(columns, stopped)
	local record = {
		kind = AB.test.kind == "run" and "run" or (AB.test.kind == "alc_only" and "alc_only" or "all"),
		when = GetDateStringFromTimestamp(GetTimeStamp()) .. " " .. GetTimeString(),
		time = GetTimeString(),
		platform = (IsConsoleUI() and "console" or "PC") .. (IsInGamepadPreferredMode() and ", gamepad UI" or ", keyboard UI"),
		target = AB.test.target and (Fmt(AB.test.target) .. " MB " .. AB.test.metric_name) or "none",
		target_mb = AB.test.target, metric_name = AB.test.metric_name, seconds = AB.test.seconds, churn = AB.test.churn,
		real = AB.test.real or nil, reload = AB.test.reload or nil, isolated = AB.test.isolated or nil, same_place = AB.test.home and true or nil, vanilla_garbage = AB.test.vanilla_garbage, fps = AB.test.fps, fair_before = AB.test.fair_before,
		clock = AB.test.clock, end_ts = GetTimeStamp(), fair_after = AB.test.fair_after,
		stopped = stopped or false, addons = AB.test.addons,
		held = AB.test.held and { bg = AB.test.held.bg and true or nil, idle = AB.test.held.idle and true or nil } or nil,
		columns = columns, compare = Compare(), continued = AB.test.continued,
		low_warning = AB.test.low_warning, held_cleaners = AB.test.held_cleaners, cleaner_timers = AB.test.cleaner_timers, force_cleaners = AB.test.force_cleaners,
		own_cleaning = AB.test.own_cleaning, player = AB.test.player, hold_s = AB.test.hold_s,
	}
	record.note = AB.test.note
	return record
end
AB.LiveColumns, AB.Compare, AB.StopTravelWatch = LiveColumns, Compare, StopTravelWatch
