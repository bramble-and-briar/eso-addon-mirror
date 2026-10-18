--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

local AB = ALCBenchmark
local CLEANERS, CLEANER_BY_KEY, UI, ALC_BUSY_MS = AB.CLEANERS, AB.CLEANER_BY_KEY, AB.UI, AB.ALC_BUSY_MS
local SHISSU_DEFAULT_DELAY_SEC = 120

local function Mgc()
	local mgc = rawget(_G, "MemoryGarbageCollector")
	if type(mgc) == "table" and type(mgc.config) == "table" and type(mgc.checkGarbage) == "function" then return mgc end
	return nil
end

local function ShissuCommand()
	local commands = rawget(_G, "SLASH_COMMANDS")
	local command = type(commands) == "table" and commands["/slm"]
	return type(command) == "function" and command or nil
end

local function ShissuSettings()
	local settings = rawget(_G, "shissuLUAMemory")
	if type(settings) == "table" and ShissuCommand() then return settings end
	return nil
end

local READY = {
	mgc = function()
		if not Mgc() then return "not loaded" end
		return nil
	end,
	shissu = function()
		if not ShissuSettings() then return "not loaded" end
		return nil
	end,
}

local CLEAN = {
	mgc = function()
		local mgc = Mgc()
		if not mgc then return false, "not loaded" end
		return pcall(mgc.checkGarbage)
	end,
	shissu = function()
		local command = ShissuCommand()
		if not command then return false, "not loaded" end
		return pcall(command, "clean")
	end,
}

function AB.CleanerBlocked(key)
	local ready = READY[key]
	if not ready then return "unknown" end
	if IsConsoleUI() then return "PC only" end
	return ready()
end

function AB.CleanerTimers()
	if IsConsoleUI() then return nil end
	local timers = {}
	local mgc = Mgc()
	if mgc then timers.mgc = { on = mgc.config.autoClear == true, every_s = (tonumber(mgc.config.refreshRate) or 10) * 60 } end
	local settings = ShissuSettings()
	if settings then timers.shissu = { on = settings.auto == true, every_s = tonumber(settings.delay) or SHISSU_DEFAULT_DELAY_SEC } end
	return next(timers) and timers or nil
end

function AB.UsableCleaners()
	local list = {}
	for _, cleaner in ipairs(CLEANERS) do
		if not AB.CleanerBlocked(cleaner.key) then list[#list + 1] = cleaner end
	end
	return list
end

function AB.CleanerName(key)
	local cleaner = CLEANER_BY_KEY[key]
	return cleaner and cleaner.name or tostring(key)
end

function AB.HoldCleaners()
	if IsConsoleUI() then return end
	for _, cleaner in ipairs(CLEANERS) do EVENT_MANAGER:UnregisterForUpdate(cleaner.timer) end
end

local function ShissuTick()
	local settings = ShissuSettings()
	if not (settings and settings.auto == true) then return end
	if settings.chat == true then
		ShissuCommand()("clean")
	else
		collectgarbage("collect")
	end
end

function AB.ReleaseCleaners()
	if IsConsoleUI() then return end
	local mgc = Mgc()
	if mgc and type(mgc.setRefreshTimer) == "function" then pcall(mgc.setRefreshTimer) end
	local settings = ShissuSettings()
	if settings and settings.auto == true then
		local delay = tonumber(settings.delay) or SHISSU_DEFAULT_DELAY_SEC
		EVENT_MANAGER:RegisterForUpdate(CLEANER_BY_KEY.shissu.timer, delay * 1000, ShissuTick)
	end
end

function AB.HeldCleaners()
	local held = {}
	for _, cleaner in ipairs(CLEANERS) do
		if not AB.CleanerBlocked(cleaner.key) then held[#held + 1] = cleaner.key end
	end
	return #held > 0 and held or nil
end

function AB.RunCleaner(key)
	local clean = CLEAN[key]
	if not clean then return false, 0, false end
	local before = collectgarbage("count")
	local ok, err = clean()
	local after = collectgarbage("count")
	UI.other_busy_until = GetGameTimeMilliseconds() + ALC_BUSY_MS
	return ok == true, math.max(before - after, 0) / 1024, after < before, not ok and err or nil
end

local OWN = {
	mgc = function()
		local mgc = Mgc()
		if mgc then pcall(mgc.checkGarbage) end
	end,
	shissu = ShissuTick,
}

function AB.OwnCleanerStep(phase, now)
	local timers = AB.test.cleaner_timers
	local timer = phase.cleaner and timers and timers[phase.cleaner]
	if not (timer and timer.on and (timer.every_s or 0) > 0) then return end
	local every = timer.every_s * 1000
	phase.own_next = phase.own_next or phase.forced_at + every
	if now < phase.own_next then return end
	phase.own_next = phase.own_next + every
	local stats = phase.stats
	stats.own_runs = (stats.own_runs or 0) + 1
	if phase.cleaner == "mgc" and AB.test.sim_combat then return AB.PLAYER.Held(phase, "mgc") end
	local before = collectgarbage("count")
	OWN[phase.cleaner]()
	local after = collectgarbage("count")
	UI.other_busy_until = GetGameTimeMilliseconds() + ALC_BUSY_MS
	stats.last_count = after
	if after >= before then return end
	local freed = (before - after) / 1024
	stats.other_cleanups, stats.other_freed = (stats.other_cleanups or 0) + 1, (stats.other_freed or 0) + freed
	stats.own_cleanups = (stats.own_cleanups or 0) + 1
	stats.events[#stats.events + 1] = { at = math.floor((now - stats.started) / 100 + 0.5) / 10, cleaner = phase.cleaner, freed = math.floor(freed * 100 + 0.5) / 100, own = true }
end

function AB.ForceClean()
	local before = collectgarbage("count")
	collectgarbage("collect")
	local after = collectgarbage("count")
	UI.other_busy_until = GetGameTimeMilliseconds() + ALC_BUSY_MS
	return math.max(before - after, 0) / 1024, after < before
end

function AB.ForcingCleaners()
	return AB.saved ~= nil and AB.saved.force_cleaners == true
end

function UI.OtherBusy(now)
	return now < (UI.other_busy_until or 0)
end
