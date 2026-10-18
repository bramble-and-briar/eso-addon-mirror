--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

APHFPSGraphCore = APHFPSGraphCore or {}
local FG = APHFPSGraphCore

FG.name = "APH-FPSGraph"
FG.VERSION = "2026.10.15.14.36"

function FG.L(key, ...)
	local id = _G["SI_APHFPS_" .. key]
	local text = id and GetString(id) or key
	if select("#", ...) > 0 then return string.format(text, ...) end
	return text
end

local DEFAULTS = {
	enabled = true,
	graph_seconds = 60,
	bucket_ms = 500,
	target_fps = 60,
	top_fps = 0,
	stutter_ms = 50,
	ping_warn_ms = 150,
	show_lows = true,
	show_frametime = true,
	show_ping = true,
	show_memory = true,
	show_graph = true,
	detail_level = 4,
	screen_position = "custom",
	window_opacity = 1,
	graph_opacity = 1,
	text_opacity = 1,
	locked = false,
	everywhere = false,
	measure_hidden = false,
	record_loads = true,
	record_seconds = 0,
	rec_status = true,
	pad_hints = true,
	chat_logs = false,
	width = 826,
	height = 479,
	warned_about_libraries = false,
}
FG.DEFAULTS = DEFAULTS

local logger

function FG.ChatLogsOn()
	return FG.saved == nil or FG.saved.chat_logs ~= false
end

function FG.Print(text, always)
	if not always and not FG.ChatLogsOn() then return false end
	logger = logger or LibAPH.CreateChatLogger("FPS", "9CD04C")
	logger:Print(text)
	return true
end

function FG.ResetToDefaults()
	for key, value in pairs(DEFAULTS) do FG.saved[key] = value end
	FG.saved.x, FG.saved.y, FG.saved.point = nil, nil, nil
	FG.saved.summary_x, FG.saved.summary_y, FG.saved.summary_point = nil, nil, nil
	FG.saved.summary_w, FG.saved.summary_h = nil, nil
	FG.saved.timeline_x, FG.saved.timeline_y, FG.saved.timeline_point = nil, nil, nil
	FG.saved.timeline_w, FG.saved.timeline_h = nil, nil
	FG.Apply()
end

function FG.IsShown()
	return FG.Graph ~= nil and FG.Graph.IsOpen()
end

function FG.ShouldMeasure()
	return (FG.saved.enabled and FG.IsShown()) or FG.saved.measure_hidden == true or FG.Sampler.IsRecording()
end

local MAX_RUNS = IsConsoleUI() and 25 or 50
FG.MAX_RUNS = MAX_RUNS
FG.view = { show = nil, compare = nil }

function FG.Runs() return FG.saved.runs end

function FG.DescribeRun(run)
	if not run then return FG.L("THIS_RUN") end
	local text = string.format("%s  %d frames  %.2f s", run.name or GetDateStringFromTimestamp(run.when or 0), run.frames or 0, run.seconds or 0)
	local status = FG.Sampler.RunStatus(run)
	if status == "changed" then return text .. FG.L("CHANGED_TAG") end
	if status == "not_sealed" then return text .. FG.L("NOT_SEALED_TAG") end
	if status == "other_player" then return text .. FG.L("OTHER_PLAYER_TAG") end
	if status == "other_server" then return text .. FG.L("OTHER_SERVER_TAG") end
	return text
end

function FG.SealNote(run)
	local status = FG.Sampler.RunStatus(run)
	if status == "changed" then return FG.L("CHANGED_AFTER_RECORDING") end
	if status == "other_player" then return FG.L("RECORDED_BY_OTHER_PLAYER", tostring(run.seal_account), tostring(run.seal_world)), true end
	if status == "other_server" then return FG.L("RECORDED_ON_OTHER_SERVER", tostring(run.seal_world)), true end
	if status ~= "not_sealed" then return nil end
	if run.unsealed == "progress" then return FG.L("NOT_SEALED_PROGRESS") end
	if run.unsealed == "no_seal" then return FG.L("NOT_SEALED_NO_SEAL") end
	return FG.L("NOT_SEALED")
end

function FG.RenameRun(run, text)
	if type(run) ~= "table" then return false end
	text = zo_strtrim(text or "")
	run.name = text ~= "" and text or nil
	FG.RefreshResults()
	return true
end

function FG.DeleteRun(run)
	local runs = FG.Runs()
	for index = #runs, 1, -1 do
		if runs[index] == run then
			table.remove(runs, index)
			if FG.view.show == run then FG.view.show = nil end
			if FG.view.compare == run then FG.view.compare = nil end
			FG.RefreshResults()
			return true
		end
	end
	return false
end

function FG.RefreshResults()
	if FG.Summary then FG.Summary.Refresh() end
	if FG.Timeline then FG.Timeline.Refresh() end
	if FG.Pad then FG.Pad.Refresh() end
end

function FG.SetShowing(run)
	FG.view.show = run
	FG.RefreshResults()
end

function FG.SetCompare(run)
	FG.view.compare = run
	FG.RefreshResults()
end

local aside = { active = false, summary = false, timeline = false }
local RECORD_STOP_MB = 65
local GUARD_JOB = "APHFPSGraph_RecordGuard"
local GUARD_MS = 1000
local guarding = false

function FG.RecordMemoryStopMB() return RECORD_STOP_MB end

local function GuardRecording()
	if not FG.Sampler.IsRecording() then return end
	local used = LibAPH.GetAddOnMemoryLimitMB and LibAPH.GetAddOnMemoryLimitMB()
	if type(used) == "number" and used >= RECORD_STOP_MB then
		FG.Print(FG.L("RECORD_STOPPED_FOR_MEMORY", used, RECORD_STOP_MB), true)
		FG.StopRecording()
	end
end

local function WatchRecording()
	local wanted = IsConsoleUI() and FG.Sampler.IsRecording()
	if wanted and not guarding then
		guarding = true
		EVENT_MANAGER:RegisterForUpdate(GUARD_JOB, GUARD_MS, GuardRecording)
	elseif not wanted and guarding then
		guarding = false
		EVENT_MANAGER:UnregisterForUpdate(GUARD_JOB)
	end
end

function FG.IsSteppedAside() return aside.active end

local function StepAside()
	if (FG.saved.record_seconds or 0) <= 0 or not FG.Graph.RecStatusOn() then return false end
	aside.active = true
	aside.summary = FG.Summary.IsShown()
	aside.timeline = FG.Timeline.IsShown()
	if aside.summary then FG.Summary.Hide() end
	if aside.timeline then FG.Timeline.Hide() end
	return true
end

local function ComeBack()
	if not aside.active then return false end
	aside.active = false
	if aside.summary then FG.Summary.Show() end
	if aside.timeline then FG.Timeline.Show() end
	aside.summary, aside.timeline = false, false
	return true
end

function FG.StartRecording()
	if not FG.Sampler.StartRecording() then
		FG.Print(FG.L("ALREADY_RECORDING"), true)
		return false
	end
	StepAside()
	FG.Apply()
	FG.Print(FG.L("RECORDING_STARTED"))
	return true
end

function FG.StopRecording()
	if not FG.Sampler.IsRecording() then
		FG.Print(FG.L("NOT_RECORDING"), true)
		return false
	end
	local run = FG.Sampler.StopRecording()
	FG.Loads.Forget()
	ComeBack()
	if run.frames == 0 then
		FG.Print(FG.L("NOTHING_MEASURED_YET"), true)
	else
		local runs = FG.Runs()
		runs[#runs + 1] = run
		while #runs > MAX_RUNS do table.remove(runs, 1) end
		FG.view.show = run
		FG.Print(FG.L("RECORDING_SAVED", FG.FormatDuration(run.seconds), run.avg_fps, run.low1_fps, run.stutters))
	end
	FG.Apply()
	FG.RefreshResults()
	return true
end

function FG.DeleteLastRun()
	local runs = FG.Runs()
	local gone = table.remove(runs)
	if gone == FG.view.show then FG.view.show = nil end
	if gone == FG.view.compare then FG.view.compare = nil end
	FG.RefreshResults()
end

function FG.DeleteAllRuns()
	FG.saved.runs = {}
	FG.view.show, FG.view.compare = nil, nil
	FG.RefreshResults()
end

function FG.Apply()
	if not FG.saved then return false end
	if FG.saved.enabled and not aside.active then FG.Graph.Open() else FG.Graph.Close() end
	FG.Graph.Refresh()
	FG.Loads.Apply()
	if FG.ShouldMeasure() then FG.Sampler.Start() else FG.Sampler.Stop() end
	FG.Graph.RefreshRecStatus()
	WatchRecording()
	if FG.Pad then
		if FG.Pad.IsFocused() and not FG.Pad.Active() then FG.Pad.Stop(true) else FG.Pad.Refresh() end
	end
	return true
end

function FG.Toggle()
	FG.saved.enabled = not FG.saved.enabled
	FG.Apply()
	return FG.saved.enabled
end

function FG.ResetStats()
	FG.Sampler.Reset()
	FG.Graph.Refresh()
	FG.Print(FG.L("STATS_RESET"))
end

function FG.Report()
	local s = FG.Sampler.SessionStats()
	if s.frames == 0 then
		FG.Print(FG.L("NOTHING_MEASURED_YET"), true)
		return false
	end
	FG.Print(FG.L("SESSION_REPORT", FG.FormatDuration(s.seconds), s.avg_fps, s.low1_fps, s.low01_fps,
		s.avg_ms, s.p99_ms, s.stutters, FG.saved.stutter_ms), true)
	return true
end

function FG.FormatDuration(seconds)
	seconds = math.floor(seconds + 0.5)
	if seconds >= 3600 then
		return string.format("%d:%02d:%02d", math.floor(seconds / 3600), math.floor(seconds / 60) % 60, seconds % 60)
	end
	return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

function FG.Command(args)
	local word = zo_strlower(zo_strtrim(args or ""))
	if word == "reset" then return FG.ResetStats() end
	if word == "report" then return FG.Report() end
	if word == "record" then return FG.StartRecording() end
	if word == "stop" then return FG.StopRecording() end
	return FG.Toggle()
end

local function Init()
	LibAPH.RegisterAddonDependencies(FG.name, { "LibAPH" }, { "LibAddonMenu-2.0", "LibHarvensAddonSettings" })
	FG.saved = ZO_SavedVars:NewAccountWide("APHFPSGraph", 1, GetWorldName() or "Default", DEFAULTS)
	for key, value in pairs(DEFAULTS) do
		if FG.saved[key] == nil then FG.saved[key] = value end
	end
	FG.saved.runs = FG.saved.runs or {}
	FG.Loads.Resume()
	SLASH_COMMANDS["/fpsgraph"] = FG.Command

	LibAPH.RunInitStages(FG.name, {
		function() end,
		FG.BuildSettingsPanel,
		FG.Apply,
	})
end

EVENT_MANAGER:RegisterForEvent(FG.name, EVENT_ADD_ON_LOADED, function(_, name)
	if name ~= FG.name then return end
	EVENT_MANAGER:UnregisterForEvent(FG.name, EVENT_ADD_ON_LOADED)
	Init()
end)
