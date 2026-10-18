--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

local AB = ALCBenchmark
local ClampSeconds, DEFAULT_SECONDS, ClampChurn, DEFAULT_CHURN_MB, UI, StartAB = AB.ClampSeconds, AB.DEFAULT_SECONDS, AB.ClampChurn, AB.DEFAULT_CHURN_MB, AB.UI, AB.StartAB
local StartRun, Say, ChunkKB, NAME, FillStep, Finish = AB.StartRun, AB.Say, AB.ChunkKB, AB.NAME, AB.FillStep, AB.Finish
local ClearResults, Help = AB.ClearResults, AB.Help

ZO_CreateStringId("SI_BINDING_NAME_ALCBENCH_TOGGLE", "Show or hide ALC Benchmark")
ZO_CreateStringId("SI_BINDING_NAME_ALCBENCH_FOCUS", "Control ALC Benchmark with a controller")

local function Command(text)
	local words = {}
	for word in string.gmatch(text or "", "%S+") do words[#words + 1] = string.lower(word) end
	local verb = words[1] or ""
	local numbers, flags = {}, {}
	for index = 2, #words do
		local number = tonumber(words[index])
		if number then numbers[#numbers + 1] = number else flags[words[index]] = true end
	end
	local seconds = ClampSeconds(numbers[1] or DEFAULT_SECONDS)
	local churn = ClampChurn(numbers[2] or DEFAULT_CHURN_MB)
	local opts = { real = flags.real or UI.On("real_world"), reload = flags.reload or UI.On("reload_phases") }
	if verb == "alc" then
		StartAB(seconds, churn, opts)
	elseif verb == "alconly" then
		StartAB(seconds, churn, opts, true)
	elseif verb == "vanilla" then
		StartRun(seconds, churn, opts)
	elseif verb == "setfps" and not IsConsoleUI() then
		AB.GS.SetFps(words[2])
	elseif verb == "memory" then
		AB.MEM.Toggle()
	elseif verb == "fill" then
		if AB.test then return Say("Not while a test is running; extra garbage would skew its numbers.") end
		ChunkKB()
		AB.fill_left = math.max(1, tonumber(words[2]) or 50)
		EVENT_MANAGER:RegisterForUpdate(NAME .. "_Fill", 0, FillStep)
	elseif verb == "stop" then
		if AB.test then Finish(true) elseif AB.LOAD.run then AB.LOAD.Stop() else Say("Nothing is running.") end
	elseif verb == "clear" then
		ClearResults()
	elseif verb == "help" then
		Help()
	else
		ALCBenchmark.Toggle()
	end
end

EVENT_MANAGER:RegisterForEvent(NAME, EVENT_ADD_ON_LOADED, function(_, addon_name)
	if addon_name ~= NAME then return end
	EVENT_MANAGER:UnregisterForEvent(NAME, EVENT_ADD_ON_LOADED)
	LibAPH.RegisterAddonDependencies(NAME, { "LibAPH" }, { "AutoLuaMemoryCleaner" })
	AB.saved = ZO_SavedVars:NewAccountWide("ALCBenchmarkResults", 1, GetWorldName() or "Default", {})
	SLASH_COMMANDS["/alcbench"] = Command
	AB.bug_reporter = LibAPH.CreateAddonBugReporter({
		addonName = NAME,
		title = "ALC Benchmark",
		version = AB.VERSION,
		boxName = "ALCBenchmarkBugReportBox",
	})
	if not IsConsoleUI() then
		SLASH_COMMANDS["/alcbenchbugreport"] = AB.bug_reporter.Show
		SLASH_COMMANDS["/alcbenchbug"] = AB.bug_reporter.Show
	end
	if GetDisplayName() == "@APHONlC" then
		SLASH_COMMANDS["/alcbenchsimulateerror"] = function()
			zo_callLater(function() error("ALCBenchmark: THIS IS A TEST ERROR") end, 1)
		end
	end
	if AB.saved.memory_display then
		EVENT_MANAGER:RegisterForEvent(NAME .. "_Memory", EVENT_PLAYER_ACTIVATED, function()
			EVENT_MANAGER:UnregisterForEvent(NAME .. "_Memory", EVENT_PLAYER_ACTIVATED)
			AB.MEM.Set(true, true)
		end)
	end
	if AB.saved.resume or AB.saved.partial then
		EVENT_MANAGER:RegisterForEvent(NAME .. "_Resume", EVENT_PLAYER_ACTIVATED, function()
			EVENT_MANAGER:UnregisterForEvent(NAME .. "_Resume", EVENT_PLAYER_ACTIVATED)
			AB.Resume()
		end)
	end
end)
