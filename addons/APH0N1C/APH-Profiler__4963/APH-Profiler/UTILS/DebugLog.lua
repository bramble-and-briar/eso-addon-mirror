--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

local APHP = APHProfilerCore

local TAG = "APH-Profiler"
local logger

local FUNCS_LOGGED = 3

function APHP.GetDebugLogger()
	if logger ~= nil then return logger or nil end
	if IsConsoleUI() or type(LibDebugLogger) ~= "table" or type(LibDebugLogger.Create) ~= "function" then
		logger = false
		return nil
	end
	logger = LibDebugLogger:Create(TAG)
	return logger
end

function APHP.ResetDebugLogger()
	logger = nil
	return true
end

function APHP.LogReportLines(report)
	local log = APHP.GetDebugLogger()
	if not log or not report then return 0 end

	local written = 0
	local function Write(level, text)
		log:Log(level, "%s", text)
		written = written + 1
	end
	local info, debug = LibDebugLogger.LOG_LEVEL_INFO, LibDebugLogger.LOG_LEVEL_DEBUG

	Write(info, string.format("run: %d frames over %.1f s, add-on Lua %.2f ms",
		report.frames or 0, (report.elapsed_ms or 0) / 1000, report.measured_ms or 0))

	local rows = report.rows or {}
	for index = 1, math.min(#rows, APHP.GetListLimit()) do
		local row = rows[index]
		Write(info, string.format("%d. %s own %.2f ms total %.2f ms %.4f ms/frame peak %.2f ms %d calls",
			index, LibAPH.StripColors(row.owner), row.own, row.total,
			row.per_frame or 0, row.peak, row.calls))
		for f = 1, math.min(#(row.funcs or {}), FUNCS_LOGGED) do
			local entry = row.funcs[f]
			Write(debug, string.format("     %.2f ms self %.2f ms wall %d calls %s", entry.own, entry.wall or 0, entry.calls, entry.label))
		end
	end
	if #rows > APHP.GetListLimit() then
		Write(info, string.format("%d more add-ons below that, all smaller", #rows - APHP.GetListLimit()))
	end
	return written
end

function APHP.QuietDebugLoggerOnConsole()
	if not IsConsoleUI() or APHP.saved.ldl_console_quieted then return false end
	local lib = LibDebugLogger
	if type(lib) ~= "table" or type(lib.GetMinLogLevel) ~= "function" then return false end

	APHP.saved.ldl_console_quieted = true
	if lib:GetMinLogLevel() ~= lib.DEFAULT_SETTINGS.minLogLevel then return false end
	lib:SetMinLogLevel(lib.LOG_LEVEL_ERROR)
	APHP.Print(APHP.L("LIBDEBUGLOGGER_NOW_KEEPS_ERRORS_ONLY_SINCE"))
	return true
end
