--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

local APHP = APHProfilerCore

local PANEL_ID = "APHProfilerOptions"
local REQUIRED_LAM = 30
local REQUIRED_LHAS = 1

local WARN_TEMPLATES = {
	missing = APHP.L("IS_NOT_INSTALLED_INSTALL_OR"),
	disabled = APHP.L("IS_INSTALLED_BUT_SWITCHED_OFF_TURN"),
	old = APHP.L("IS_THIS_NEEDS_UPDATE_IT_OR"),
}

local function SavedRunCount()
	return #APHP.GetRuns()
end

function APHP.CheckSettingsLibraries()
	local lam_version, lam_enabled = LibAPH.CheckLibraryVersion("LibAddonMenu-2.0")
	local alerts = {}

	local lam_alert = LibAPH.BuildLibraryWarning(WARN_TEMPLATES, "LibAddonMenu", "LAM",
		lam_version, lam_enabled, REQUIRED_LAM, APHP.L("THE_SETTINGS_PANEL_WILL_NOT_OPEN"))
	if lam_alert then alerts[#alerts + 1] = lam_alert end

	if IsConsoleUI() then
		local lhas_version, lhas_enabled = LibAPH.CheckLibraryVersion("LibHarvensAddonSettings")
		local lhas_alert = LibAPH.BuildLibraryWarning(WARN_TEMPLATES, "LibHarvensAddonSettings", "LHAS",
			lhas_version, lhas_enabled, REQUIRED_LHAS, APHP.L("THE_SETTINGS_PANEL_WILL_NOT_OPEN_2"))
		if lhas_alert then alerts[#alerts + 1] = lhas_alert end
	end

	return alerts
end

function APHP.WarnAboutSettingsLibraries()
	local alerts = APHP.CheckSettingsLibraries()
	if #alerts == 0 then return false end
	if APHP.saved.warned_about_libraries then return false end

	APHP.saved.warned_about_libraries = true
	for _, alert in ipairs(alerts) do APHP.Print(alert) end
	return true
end

function APHP.SettingsControls()
	local data = {
		{
			type = "description",
			title = APHP.L("HOW_IT_WORKS"),
			text = APHP.L("START_A_RECORDING_REPRODUCE_THE_STUTTER"),
		},
		{
			type = "button",
			name = APHP.L("START_RECORDING"),
			func = function() APHP.Start() end,
			disabled = function() return APHP.IsRunning() end,
			width = "half",
		},
		{
			type = "button",
			name = APHP.L("OPEN_RESULTS"),
			func = function()
				if IsConsoleUI() or IsInGamepadPreferredMode() then return APHP.StartPadControl() end
				return APHP.ShowHud()
			end,
			width = "half",
		},
		{
			type = "button",
			name = APHP.L("STOP_RECORDING"),
			func = function() APHP.Stop() end,
			disabled = function() return not APHP.IsRunning() end,
			width = "half",
		},
		{
			type = "button",
			name = APHP.L("OPEN_LOAD_TIMES"),
			func = function()
				if IsConsoleUI() or IsInGamepadPreferredMode() then APHP.StartPadControl() end
				return APHP.ShowLoadTimes()
			end,
			width = "half",
		},
		{
			type = "checkbox",
			name = APHP.L("SCAN_LOAD_TIMES"),
			tooltip = APHP.L("SCAN_LOAD_TIMES_TIP"),
			getFunc = function() return APHP.saved.scan_load_times end,
			setFunc = function(value)
				APHP.saved.scan_load_times = value
				if value then APHP.saved.profile_ui_load = false end
			end,
			disabled = function() return APHP.IsRunning() end,
			default = APHP.DEFAULTS.scan_load_times,
		},
		{
			type = "checkbox",
			name = APHP.L("PROFILE_UI_LOAD"),
			tooltip = APHP.L("PROFILE_UI_LOAD_TIP"),
			getFunc = function() return APHP.saved.profile_ui_load end,
			setFunc = function(value)
				APHP.saved.profile_ui_load = value
				if value then APHP.saved.scan_load_times = false end
			end,
			disabled = function() return APHP.IsRunning() end,
			default = APHP.DEFAULTS.profile_ui_load,
		},
		{
			type = "dropdown",
			name = APHP.L("SCAN_LENGTH"),
			choices = { APHP.L("UNTIL_I_PRESS_STOP"), APHP.L("TIMED") },
			choicesValues = { APHP.SCAN_UNTIL_STOP, APHP.SCAN_TIMED },
			getFunc = function() return APHP.saved.scan_mode end,
			setFunc = function(value)
				APHP.saved.scan_mode = value
				APHP.ApplyScanLimits()
			end,
			default = APHP.DEFAULTS.scan_mode,
		},
		{
			type = "slider",
			name = APHP.L("TIMED_SCAN_SECONDS"),
			min = APHP.ScanRange().min, max = APHP.ScanRange().slider_max, step = APHP.ScanRange().step,
			getFunc = function() return APHP.ScanSeconds() end,
			setFunc = function(value)
				APHP.saved.scan_seconds = value
				APHP.ApplyScanLimits()
			end,
			disabled = function() return not APHP.IsTimedScan() end,
			default = APHP.DEFAULTS.scan_seconds,
		},
		{
			type = "checkbox",
			name = APHP.L("SEND_RUNS_TO_LIBDEBUGLOGGER"),
			getFunc = function() return APHP.saved.log_to_debuglogger end,
			setFunc = function(value) APHP.saved.log_to_debuglogger = value end,
			default = APHP.DEFAULTS.log_to_debuglogger,
			disabled = function() return APHP.GetDebugLogger() == nil end,
		},
		{
			type = "checkbox",
			name = APHP.L("OPEN_THE_RESULTS_WINDOW_AFTER_A"),
			getFunc = function() return APHP.saved.open_window_after_scan end,
			setFunc = function(value) APHP.saved.open_window_after_scan = value end,
			default = APHP.DEFAULTS.open_window_after_scan,
		},
		{
			type = "checkbox",
			name = APHP.L("SCAN_STATUS_UNDER_COMPASS"),
			tooltip = APHP.L("SCAN_STATUS_UNDER_COMPASS_TIP"),
			getFunc = function() return APHP.saved.scan_status end,
			setFunc = function(value)
				APHP.saved.scan_status = value
				APHP.RefreshScanStatus()
			end,
			default = APHP.DEFAULTS.scan_status,
		},
		{
			type = "checkbox",
			name = APHP.L("CONTROLLER_BUTTON_HINTS"),
			getFunc = function() return APHP.saved.pad_hints end,
			setFunc = function(value)
				APHP.saved.pad_hints = value
				APHP.RefreshPadHints()
			end,
			default = APHP.DEFAULTS.pad_hints,
		},
		{
			type = "checkbox",
			name = APHP.L("CHAT_LOGS"),
			getFunc = function() return APHP.saved.chat_logs end,
			setFunc = function(value) APHP.saved.chat_logs = value end,
			default = APHP.DEFAULTS.chat_logs,
		},
		{
			type = "checkbox",
			name = APHP.L("LEAVE_APH_PROFILER_OUT_OF_ITS"),
			getFunc = function() return APHP.saved.exclude_self end,
			setFunc = function(value) APHP.saved.exclude_self = value end,
			default = APHP.DEFAULTS.exclude_self,
		},
		{
			type = "checkbox",
			name = APHP.L("LEAVE_LIBRARIES_OUT_OF_THE_RESULTS"),
			tooltip = APHP.L("A_LIBRARY_S_TIME_IS_SPENT"),
			getFunc = function() return APHP.saved.exclude_libraries end,
			setFunc = function(value) APHP.saved.exclude_libraries = value end,
			default = APHP.DEFAULTS.exclude_libraries,
		},
		{
			type = "slider",
			name = APHP.L("FRAMES_READ_PER_TICK"),
			tooltip = APHP.L("HOW_MUCH_OF_THE_RECORDING_IS"),
			min = 1, max = 200, step = 1,
			getFunc = function() return APHP.saved.frames_per_tick end,
			setFunc = function(value) APHP.saved.frames_per_tick = APHP.LimitFor("frames", value) end,
			default = APHP.DEFAULTS.frames_per_tick,
		},
		{
			type = "slider",
			name = APHP.L("ADD_ONS_LISTED_IN_THE_RESULTS"),
			min = 3, max = 50, step = 1,
			getFunc = function() return APHP.saved.report_rows end,
			setFunc = function(value)
				APHP.saved.report_rows = value
				APHP.RefreshHud()
			end,
			default = APHP.DEFAULTS.report_rows,
		},
		{
			type = "slider",
			name = APHP.L("FUNCTIONS_KEPT_PER_ADD_ON"),
			tooltip = APHP.L("HOW_MANY_FUNCTIONS_THE_RESULTS_WINDOW"),
			min = 5, max = 100, step = 5,
			getFunc = function() return APHP.saved.detail_rows end,
			setFunc = function(value) APHP.saved.detail_rows = APHP.LimitFor("funcs", value) end,
			default = APHP.DEFAULTS.detail_rows,
		},
		{
			type = "checkbox",
			name = APHP.L("SHOW_THE_PREVIOUS_SCAN_UNDERNEATH"),
			tooltip = APHP.L("KEEPS_THE_SCAN_BEFORE_THIS_ONE"),
			getFunc = function() return APHP.saved.show_previous_scan end,
			setFunc = function(value)
				APHP.saved.show_previous_scan = value
				APHP.RefreshHud()
			end,
			default = APHP.DEFAULTS.show_previous_scan,
		},
		{
			type = "slider",
			name = APHP.L("SCANS_KEPT"),
			tooltip = APHP.L("HOW_MANY_FINISHED_SCANS_ARE_REMEMBERED"),
			min = APHP.MIN_MAX_RUNS, max = APHP.MAX_MAX_RUNS, step = 1,
			getFunc = function() return APHP.GetMaxRuns() end,
			setFunc = function(value)
				APHP.saved.max_saved_runs = APHP.LimitFor("runs", value)
				APHP.TrimRuns()
			end,
			default = APHP.DEFAULTS.max_saved_runs,
		},
		{
			type = "slider",
			name = APHP.L("ADD_ONS_KEPT_PER_SCAN"),
			tooltip = APHP.L("HOW_MANY_ADD_ONS_A_FINISHED"),
			min = APHP.MIN_ROWS_PER_RUN, max = APHP.MAX_ROWS_PER_RUN, step = 1,
			getFunc = function() return APHP.GetRowsPerRun() end,
			setFunc = function(value) APHP.saved.max_rows_per_run = APHP.LimitFor("rows", value) end,
			default = APHP.DEFAULT_ROWS_PER_RUN,
		},
		{
			type = "button",
			name = "|cFF0000" .. APHP.L("RESET_HUD_SIZE") .. "|r",
			warning = APHP.L("WARN_RESET_HUD_SIZE"),
			isDangerous = true,
			func = function() APHP.ResetHudSize() end,
			width = "half",
		},
		{
			type = "checkbox",
			name = APHP.L("LOCK_THE_HUD_IN_PLACE"),
			getFunc = function() return APHP.saved.hud_locked end,
			setFunc = function(value)
				APHP.saved.hud_locked = value
				APHP.ApplyHudLock()
			end,
			default = APHP.DEFAULTS.hud_locked,
		},
		{
			type = "description",
			title = APHP.L("SAVED_RUNS"),
			text = function()
				local count = SavedRunCount()
				if count == 0 then return APHP.L("NO_RUNS_SAVED_YET_THE_NEXT") end
				return string.format(APHP.L("SCAN_SAVED_UP_TO_OF_AT"),
					count, count == 1 and "" or "s", APHP.GetMaxRuns(), APHP.GetRowsPerRun(), APHP.GetStoredNameCount())
			end,
		},
		{
			type = "button",
			name = APHP.L("EXPORT_LAST_RESULT"),
			func = function() APHP.ShowExport() end,
			width = "half",
		},
		{
			type = "button",
			name = "|cFF0000" .. APHP.L("RESET_TO_DEFAULTS") .. "|r",
			warning = APHP.L("PUTS_EVERY_SETTING_ON_THIS_PANEL"),
			isDangerous = true,
			func = function()
				APHP.ResetToDefaults()
				APHP.Print(APHP.L("SETTINGS_ARE_BACK_TO_THEIR_DEFAULTS"), true)
			end,
			width = "half",
		},
		{
			type = "button",
			name = APHP.L("WIPE_LAST_RUN"),
			warning = APHP.L("THROWS_AWAY_THE_MOST_RECENT_SAVED"),
			isDangerous = true,
			func = function() APHP.WipeLatestResult() end,
			width = "half",
		},
		{
			type = "button",
			name = APHP.L("WIPE_ALL_RESULTS"),
			warning = APHP.L("THROWS_AWAY_EVERY_SAVED_RUN"),
			isDangerous = true,
			func = function() APHP.WipeAllResults() end,
			width = "half",
		},
	}

	if IsConsoleUI() then
		local pc_only = { [APHP.L("SEND_RUNS_TO_LIBDEBUGLOGGER")] = true, [APHP.L("EXPORT_LAST_RESULT")] = true }
		for index = #data, 1, -1 do
			if pc_only[data[index].name] then table.remove(data, index) end
		end
	end

	if not APHP.CanProfileUiLoad() then
		for index = #data, 1, -1 do
			if data[index].name == APHP.L("PROFILE_UI_LOAD") then table.remove(data, index) end
		end
	end

	return data
end

function APHP.BuildSettingsPanel()
	local lam_version, lam_enabled = LibAPH.CheckLibraryVersion("LibAddonMenu-2.0")
	if not lam_enabled or lam_version < REQUIRED_LAM then
		APHP.WarnAboutSettingsLibraries()
		return false
	end

	local lam = LibAddonMenu2
	if not lam then return false end

	local header = {
		type = "panel",
		name = "|c9CD04CAPH-Profiler|r",
		displayName = "|c00FFFFAPH-Profiler|r",
		author = "|ca500f3A|r|cb400e6P|r|cc300daH|r|cd200cdO|r|ce100c1NlC|r",
		version = APHP.VERSION,
		registerForRefresh = true,
		translation = "https://www.esoui.com/portal.php?id=360&a=featurereq",
		donation = "https://buymeacoffee.com/aph0nlc",
	}

	lam:RegisterAddonPanel(PANEL_ID, header)
	lam:RegisterOptionControls(PANEL_ID, APHP.SettingsControls())
	APHP.WarnAboutSettingsLibraries()
	return true
end
