--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

local AB = ALCBenchmark
local UI, ALC_BUSY_MS, LuaMB, PoolMB, PoolCapacityMB, PoolLimitMB, POOL_FULL_MARGIN_MB = AB.UI, AB.ALC_BUSY_MS, AB.LuaMB, AB.PoolMB, AB.PoolCapacityMB, AB.PoolLimitMB, AB.POOL_FULL_MARGIN_MB
local METHOD_NAMES = AB.METHOD_NAMES

local function NewStats(label)
	return { label = label, frames = 0, lua_sum = 0, pool_sum = 0, samples = 0,
		series = { lua = {}, pool = {}, away = {} }, events = {}, methods = {}, lowmem = {}, warnings = 0, away_s = 0,
		pool_samples = 0, made_kb = 0, game_lua_kb = 0, game_pool = 0, game_cleanups = 0, lua_peak = 0, pool_peak = 0, cleanups = 0, freed_lua = 0, freed_pool = 0, started = GetGameTimeMilliseconds() }
end

function UI.AlcBusy(now)
	local alc = AB.Alc()
	if (LibAPH.IsCleanupRunning and LibAPH.IsCleanupRunning()) or (LibAPH.IsStepCleanupRunning and LibAPH.IsStepCleanupRunning()) or (alc and alc.is_rescuing and alc.is_rescuing()) then
		UI.alc_busy_until = now + ALC_BUSY_MS
		return true
	end
	return now < (UI.alc_busy_until or 0)
end

local function Sample(stats)
	local lua, pool = LuaMB(), PoolMB()
	local series = stats.series
	series.lua[#series.lua + 1] = math.floor(lua * 10 + 0.5) / 10
	series.pool[#series.pool + 1] = pool and math.floor(pool * 10 + 0.5) / 10 or false
	local away = not DoesGameHaveFocus()
	series.away[#series.away + 1] = away and 1 or 0
	if away then stats.away_s = stats.away_s + 1 end
	stats.samples, stats.sampled_at = stats.samples + 1, GetGameTimeMilliseconds()
	stats.lua_sum = stats.lua_sum + lua
	stats.lua_peak = math.max(stats.lua_peak, lua)
	if not pool then return end
	if stats.last_pool and pool < stats.last_pool then
		local now = GetGameTimeMilliseconds()
		if UI.OtherBusy and UI.OtherBusy(now) then
			stats.other_pool = (stats.other_pool or 0) + stats.last_pool - pool
		elseif not UI.AlcBusy(now) then
			stats.game_pool = stats.game_pool + stats.last_pool - pool
		end
	end
	stats.last_pool = pool
	stats.pool_samples = stats.pool_samples + 1
	stats.pool_sum = stats.pool_sum + pool
	stats.pool_peak = math.max(stats.pool_peak, pool)
	if not stats.full_at and pool >= PoolLimitMB() - POOL_FULL_MARGIN_MB then
		stats.full_at = (GetGameTimeMilliseconds() - stats.started) / 1000
		stats.lua_at_full = lua
	end
end

local function EndSample(stats)
	local at = stats.sampled_at or 0
	if (stats.last_game_drop or 0) > at or (AB.test and AB.test.last_alc_cleanup or 0) > at then Sample(stats) end
end

local function Finalize(stats, extra, into)
	local lua_now = LuaMB()
	local values = into or {}
	values.label = stats.label
	values.seconds = (GetGameTimeMilliseconds() - stats.started) / 1000
	values.frames = stats.frames
	values.lua_start, values.lua_end, values.lua_peak = stats.lua_start, lua_now, stats.lua_peak
	values.lua_avg = stats.samples > 0 and stats.lua_sum / stats.samples or nil
	values.made_rate = values.seconds > 0 and stats.made_kb / 1024 / values.seconds or nil
	local pooled = stats.pool_samples > 0
	values.pool_start, values.pool_end = stats.pool_start, PoolMB()
	values.pool_peak = pooled and stats.pool_peak or nil
	values.pool_avg = pooled and stats.pool_sum / stats.pool_samples or nil
	values.pool_cap = PoolCapacityMB()
	values.pool_full_at, values.lua_at_full = stats.full_at, stats.lua_at_full
	values.lua_past_full = stats.lua_at_full and math.max(stats.lua_peak, lua_now) - stats.lua_at_full or nil
	values.game_lua, values.game_pool, values.game_cleanups = stats.game_lua_kb / 1024, stats.game_pool, stats.game_cleanups
	values.cleanups, values.freed_lua, values.freed_pool = stats.cleanups, stats.freed_lua, stats.freed_pool
	values.other_runs, values.other_cleanups = stats.other_runs, stats.other_cleanups
	values.other_freed_lua, values.other_freed_pool = stats.other_freed, stats.other_pool
	values.other_forced, values.other_own_why, values.other_error = stats.other_forced, stats.other_own_why, stats.other_error
	values.window_s, values.window_kb = stats.window_s, stats.window_kb
	values.series, values.events = stats.series, stats.events
	values.away_s = stats.away_s > 0 and stats.away_s or nil
	local used = {}
	for _, mode in ipairs({ "background", "aggressive", "deep" }) do
		local used_count = stats.methods[mode]
		if used_count then used[#used + 1] = string.format("%s %dx", METHOD_NAMES[mode], used_count) end
	end
	values.methods = #used > 0 and table.concat(used, ", ") or nil
	local lowmem = {}
	for _, mode in ipairs({ "background", "aggressive", "deep", "rescue" }) do
		local used_count = stats.lowmem and stats.lowmem[mode]
		if used_count and mode == "rescue" then
			lowmem[#lowmem + 1] = string.format("%d rescue pass%s for low memory", used_count, used_count == 1 and "" or "es")
		elseif used_count then
			lowmem[#lowmem + 1] = string.format("%s %dx for low memory", METHOD_NAMES[mode], used_count)
		end
	end
	values.lowmem_methods = #lowmem > 0 and table.concat(lowmem, ", ") or nil
	values.low_warnings = (stats.warnings or 0) > 0 and stats.warnings or nil
	values.own_cleanups = stats.own_cleanups
	values.player_menus, values.player_menu_s, values.player_skipped = stats.player_menus, stats.player_menu_s, stats.player_skipped
	values.player_combats, values.player_combat_s = stats.player_combats, stats.player_combat_s
	values.player_idles, values.player_idle_s = stats.player_idles, stats.player_idle_s
	values.held_alc, values.held_mgc = stats.held_alc, stats.held_mgc
	values.acted_idle, values.acted_menu, values.acted_after_combat = stats.acted_idle, stats.acted_menu, stats.acted_after_combat
	if extra then
		for key, value in pairs(extra) do values[key] = value end
	end
	return values
end
AB.NewStats, AB.Sample, AB.EndSample, AB.Finalize = NewStats, Sample, EndSample, Finalize
