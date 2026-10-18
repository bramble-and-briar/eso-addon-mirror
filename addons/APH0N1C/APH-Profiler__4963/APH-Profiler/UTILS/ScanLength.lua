--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

local APHP = APHProfilerCore

local WATCH_NAMESPACE = "APHProfiler_ScanWatch"
local WATCH_MS = 1000
local PC_MEMORY_STOP_MB = 225
local CONSOLE_MEMORY_STOP_MB = 65
local LIMIT_EVENT = APHP.name .. "_MemoryLimit"

APHP.SCAN_UNTIL_STOP = "until_stop"
APHP.SCAN_TIMED = "timed"

local RANGE_PC = { min = 30, ref = 60, slider_max = 600, step = 5 }
local RANGE_CONSOLE = { min = 10, ref = 30, slider_max = 600, step = 5 }

local LIMITS_PC = {
	short = { runs = 50, rows = 500, funcs = 100, frames = 200 },
	long = { runs = 25, rows = 300, funcs = 50, frames = 100 },
}
local LIMITS_CONSOLE = {
	short = { runs = 15, rows = 200, funcs = 20, frames = 25 },
	long = { runs = 8, rows = 100, funcs = 10, frames = 15 },
}

function APHP.ScanRange()
	return IsConsoleUI() and RANGE_CONSOLE or RANGE_PC
end

function APHP.IsTimedScan()
	return APHP.saved.scan_mode == APHP.SCAN_TIMED
end

function APHP.ScanSeconds()
	local range = APHP.ScanRange()
	local value = APHP.saved.scan_seconds
	if type(value) ~= "number" then return range.min end
	return math.max(value, range.min)
end

local function Guarded()
	return IsConsoleUI() or APHP.IsTimedScan()
end

function APHP.ScanLimits()
	if not Guarded() then return nil end
	local range = APHP.ScanRange()
	local limits = IsConsoleUI() and LIMITS_CONSOLE or LIMITS_PC
	local seconds = APHP.IsTimedScan() and APHP.ScanSeconds() or range.ref
	local share = zo_clamp((seconds - range.min) / (range.ref - range.min), 0, 1)
	local out = {}
	for key, short in pairs(limits.short) do
		out[key] = math.floor(short + (limits.long[key] - short) * share + 0.5)
	end
	return out
end

function APHP.LimitFor(key, value)
	local limits = APHP.ScanLimits()
	if not limits or type(value) ~= "number" then return value end
	return math.min(value, limits[key])
end

local LIMITED_SETTINGS = {
	{ key = "runs", field = "max_saved_runs" },
	{ key = "rows", field = "max_rows_per_run" },
	{ key = "funcs", field = "detail_rows" },
	{ key = "frames", field = "frames_per_tick" },
}

function APHP.ApplyScanLimits()
	local limits = APHP.ScanLimits()
	if not limits then return false end
	local changed = false
	for _, entry in ipairs(LIMITED_SETTINGS) do
		local value = APHP.saved[entry.field]
		if type(value) == "number" and value > limits[entry.key] then
			APHP.saved[entry.field] = limits[entry.key]
			changed = true
		end
	end
	if changed then
		if APHP.TrimRuns then APHP.TrimRuns() end
		if LibHarvensAddonSettings and LibHarvensAddonSettings.RefreshAddonSettings then
			LibHarvensAddonSettings:RefreshAddonSettings()
		end
	end
	return changed
end

function APHP.ConsoleMemoryStopMB()
	return CONSOLE_MEMORY_STOP_MB
end

function APHP.MemoryUseMB()
	if IsConsoleUI() then return GetTotalUserAddOnMemoryPoolUsageMB() or 0, CONSOLE_MEMORY_STOP_MB end
	return collectgarbage("count") / 1024, PC_MEMORY_STOP_MB
end

local function StopForMemory(reason)
	if not APHP.IsRunning() then return end
	local elapsed = (APHP.GetRecordingElapsedMs() or 0) / 1000
	APHP.Print(string.format(APHP.L("STOPPED_AT_READING_WHAT_WAS_RECORDED"), APHP.FormatClock(elapsed), reason))
	APHP.Stop()
end

local function Watch()
	if not APHP.IsRunning() then
		APHP.StopScanWatch()
		return
	end
	local elapsed = (APHP.GetRecordingElapsedMs() or 0) / 1000
	if APHP.IsTimedScan() and elapsed >= APHP.ScanSeconds() then
		APHP.Stop()
		return
	end
	if not Guarded() then return end
	if IsConsoleUI() and ShouldWarnConsoleAddOnMemoryLimit() then
		StopForMemory(APHP.L("THE_GAME_WARNED_THAT_ADD_ON"))
		return
	end
	local used, stop_at = APHP.MemoryUseMB()
	if used >= stop_at then
		StopForMemory(string.format(APHP.L("ADD_ON_MEMORY_REACHED_MB_THE"), used, stop_at))
	end
end

function APHP.StartScanWatch()
	APHP.ApplyScanLimits()
	EVENT_MANAGER:RegisterForUpdate(WATCH_NAMESPACE, WATCH_MS, Watch)
	if IsConsoleUI() then
		EVENT_MANAGER:RegisterForEvent(LIMIT_EVENT, EVENT_CONSOLE_ADD_ONS_MEMORY_LIMIT_REACHED, function()
			StopForMemory(APHP.L("THE_GAME_WARNED_THAT_ADD_ON"))
		end)
	end
end

function APHP.StopScanWatch()
	EVENT_MANAGER:UnregisterForUpdate(WATCH_NAMESPACE)
	EVENT_MANAGER:UnregisterForEvent(LIMIT_EVENT, EVENT_CONSOLE_ADD_ONS_MEMORY_LIMIT_REACHED)
end

function APHP.CleanUpAfterScan()
	LibAPH.StepCleanup(1)
	return true
end
