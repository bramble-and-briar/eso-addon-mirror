--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

local FG = APHFPSGraphCore

local PANEL_ID = "APHFPSGraphOptions"
local REQUIRED_LAM = 30
local REQUIRED_LHAS = 1
local TOP_CHOICES = { 0, 60, 120, 144, 165, 240, 360 }

local WARN_TEMPLATES = {
	missing = FG.L("IS_NOT_INSTALLED_INSTALL_OR"),
	disabled = FG.L("IS_INSTALLED_BUT_SWITCHED_OFF_TURN"),
	old = FG.L("IS_THIS_NEEDS_UPDATE_IT_OR"),
}

function FG.CheckSettingsLibraries()
	local alerts = {}
	local lam_version, lam_enabled = LibAPH.CheckLibraryVersion("LibAddonMenu-2.0")
	local lam_alert = LibAPH.BuildLibraryWarning(WARN_TEMPLATES, "LibAddonMenu", "LAM",
		lam_version, lam_enabled, REQUIRED_LAM, FG.L("THE_SETTINGS_PANEL_WILL_NOT_OPEN"))
	if lam_alert then alerts[#alerts + 1] = lam_alert end
	if IsConsoleUI() then
		local lhas_version, lhas_enabled = LibAPH.CheckLibraryVersion("LibHarvensAddonSettings")
		local lhas_alert = LibAPH.BuildLibraryWarning(WARN_TEMPLATES, "LibHarvensAddonSettings", "LHAS",
			lhas_version, lhas_enabled, REQUIRED_LHAS, FG.L("THE_SETTINGS_PANEL_WILL_NOT_OPEN_ON_CONSOLE"))
		if lhas_alert then alerts[#alerts + 1] = lhas_alert end
	end
	return alerts
end

local function WarnAboutSettingsLibraries()
	local alerts = FG.CheckSettingsLibraries()
	if #alerts == 0 or FG.saved.warned_about_libraries then return false end
	FG.saved.warned_about_libraries = true
	for _, alert in ipairs(alerts) do FG.Print(alert) end
	return true
end

local function Set(key)
	return function(value)
		FG.saved[key] = value
		FG.Apply()
	end
end

local function Percent(key)
	return {
		get = function() return math.floor(FG.saved[key] * 100 + 0.5) end,
		set = function(value)
			FG.saved[key] = value / 100
			FG.Graph.ApplyOpacity()
		end,
		default = math.floor(FG.DEFAULTS[key] * 100 + 0.5),
	}
end

local function Hidden() return not FG.saved.enabled end

local function OpacitySlider(key, label)
	local p = Percent(key)
	return {
		type = "slider", name = FG.L(label), min = 0, max = 100, step = 5,
		getFunc = p.get, setFunc = p.set, default = p.default, disabled = Hidden,
	}
end

local function Check(key, label)
	return {
		type = "checkbox", name = FG.L(label),
		getFunc = function() return FG.saved[key] end, setFunc = Set(key), default = FG.DEFAULTS[key],
	}
end

local function TopNames()
	local names = {}
	for i, value in ipairs(TOP_CHOICES) do
		names[i] = value == 0 and FG.L("AUTOMATIC") or tostring(value)
	end
	return names
end

function FG.SettingsControls()
	return {
		{ type = "description", title = FG.L("HOW_IT_WORKS"), text = FG.L("HOW_IT_WORKS_TEXT") },
		{ type = "button", name = FG.L("OPEN_THE_WINDOW"), func = function() FG.Pad.OpenGraph() end },
		Check("show_graph", "SHOW_THE_GRAPH"),
		{
			type = "dropdown", name = FG.L("DETAIL_LEVEL"),
			choices = { FG.L("DETAIL_1"), FG.L("DETAIL_2"), FG.L("DETAIL_3"), FG.L("DETAIL_4") }, choicesValues = { 1, 2, 3, 4 },
			getFunc = function() return FG.saved.detail_level end, setFunc = Set("detail_level"),
			default = FG.DEFAULTS.detail_level,
		},
		{
			type = "dropdown", name = FG.L("SCREEN_POSITION"),
			choices = { FG.L("POS_CUSTOM"), FG.L("POS_TOP_LEFT"), FG.L("POS_TOP_CENTER"), FG.L("POS_TOP_RIGHT"),
				FG.L("POS_BOTTOM_LEFT"), FG.L("POS_BOTTOM_CENTER"), FG.L("POS_BOTTOM_RIGHT") },
			choicesValues = { "custom", "top_left", "top_center", "top_right", "bottom_left", "bottom_center", "bottom_right" },
			getFunc = function() return FG.saved.screen_position end, setFunc = Set("screen_position"),
			default = FG.DEFAULTS.screen_position,
		},
		Check("chat_logs", "CHAT_LOGS"),
		{
			type = "button", name = FG.L("START_RECORDING"), func = function() FG.StartRecording() end,
			width = "half", disabled = function() return FG.Sampler.IsRecording() end,
		},
		{
			type = "button", name = FG.L("STOP_RECORDING"), func = function() FG.StopRecording() end,
			width = "half", disabled = function() return not FG.Sampler.IsRecording() end,
		},
		{
			type = "dropdown", name = FG.L("GRAPH_LENGTH"),
			choices = { FG.L("SECONDS", 30), FG.L("SECONDS", 60), FG.L("SECONDS", 120) }, choicesValues = { 30, 60, 120 },
			getFunc = function() return FG.saved.graph_seconds end, setFunc = Set("graph_seconds"),
			default = FG.DEFAULTS.graph_seconds,
		},
		{
			type = "dropdown", name = FG.L("UPDATE_EVERY"),
			choices = { FG.L("SECONDS_DECIMAL", 0.25), FG.L("SECONDS_DECIMAL", 0.5), FG.L("SECONDS_DECIMAL", 1) },
			choicesValues = { 250, 500, 1000 },
			getFunc = function() return FG.saved.bucket_ms end, setFunc = Set("bucket_ms"),
			default = FG.DEFAULTS.bucket_ms,
		},
		{
			type = "slider", name = FG.L("TARGET_FPS"), min = 30, max = 360, step = 5,
			getFunc = function() return FG.saved.target_fps end, setFunc = Set("target_fps"),
			default = FG.DEFAULTS.target_fps,
		},
		{
			type = "dropdown", name = FG.L("GRAPH_TOP"), choices = TopNames(), choicesValues = TOP_CHOICES,
			getFunc = function() return FG.saved.top_fps end, setFunc = Set("top_fps"),
			default = FG.DEFAULTS.top_fps,
		},
		{
			type = "slider", name = FG.L("STUTTER_THRESHOLD"),
			min = 20, max = 250, step = 5,
			getFunc = function() return FG.saved.stutter_ms end, setFunc = Set("stutter_ms"),
			default = FG.DEFAULTS.stutter_ms,
		},
		Check("show_lows", "SHOW_LOWS"),
		Check("show_frametime", "SHOW_FRAMETIME"),
		Check("show_ping", "SHOW_PING"),
		{
			type = "slider", name = FG.L("PING_WARN"), min = 50, max = 500, step = 10,
			getFunc = function() return FG.saved.ping_warn_ms end, setFunc = Set("ping_warn_ms"),
			default = FG.DEFAULTS.ping_warn_ms, disabled = function() return not FG.saved.show_ping end,
		},
		Check("show_memory", "SHOW_MEMORY"),
		{ type = "header", name = FG.L("RESULTS") },
		{
			type = "button", name = FG.L("OPEN_SUMMARY"), func = function() FG.Pad.OpenResults() end, width = "half",
		},
		{
			type = "button", name = FG.L("OPEN_TIMELINE"), func = function()
				FG.Timeline.Show()
				FG.Pad.Start()
			end, width = "half",
		},
		{
			type = "button", name = "|cFF0000" .. FG.L("DELETE_LAST_RUN") .. "|r", warning = FG.L("WARN_DELETE_LAST_RUN"), isDangerous = true, func = function() FG.DeleteLastRun() end,
			width = "half", disabled = function() return #FG.Runs() == 0 end,
		},
		{
			type = "button", name = "|cFF0000" .. FG.L("DELETE_ALL_RUNS") .. "|r", warning = FG.L("WARN_DELETE_ALL_RUNS"), isDangerous = true, func = function() FG.DeleteAllRuns() end,
			width = "half", disabled = function() return #FG.Runs() == 0 end,
		},
		{ type = "header", name = FG.L("WINDOW") },
		OpacitySlider("window_opacity", "WINDOW_OPACITY"),
		OpacitySlider("graph_opacity", "GRAPH_OPACITY"),
		OpacitySlider("text_opacity", "TEXT_OPACITY"),
		{
			type = "slider", name = FG.L("WINDOW_WIDTH"), min = FG.Graph.MIN_W, max = 900, step = 10,
			getFunc = function() return FG.saved.width end, setFunc = Set("width"), default = FG.DEFAULTS.width,
		},
		{
			type = "slider", name = FG.L("WINDOW_HEIGHT"), min = FG.Graph.MIN_H, max = 600, step = 10,
			getFunc = function() return FG.saved.height end, setFunc = Set("height"), default = FG.DEFAULTS.height,
			disabled = function() return not FG.saved.show_graph end,
		},
		Check("locked", "LOCK_WINDOW"),
		Check("everywhere", "SHOW_IN_MENUS"),
		Check("measure_hidden", "MEASURE_WHILE_HIDDEN"),
		Check("rec_status", "REC_STATUS_UNDER_COMPASS"),
		{
			type = "checkbox", name = FG.L("CONTROLLER_BUTTON_HINTS"),
			getFunc = function() return FG.saved.pad_hints end,
			setFunc = function(value)
				FG.saved.pad_hints = value
				FG.Pad.Refresh()
			end,
			default = FG.DEFAULTS.pad_hints,
		},
		{
			type = "checkbox", name = FG.L("RECORD_LOADS"),
			getFunc = function() return FG.saved.record_loads end, setFunc = Set("record_loads"), default = FG.DEFAULTS.record_loads,
			disabled = function() return FG.Sampler.IsRecording() end,
		},
		{ type = "description", text = FG.L("RECORD_LOADS_TEXT") },
		{
			type = "button", name = FG.L("MOVE_WINDOW"), func = function() FG.Graph.StartMove() end,
			width = "half", disabled = function() return Hidden() or FG.Graph.IsPinned() end,
		},
		{
			type = "button", name = "|cFF0000" .. FG.L("RESET_POSITION") .. "|r", warning = FG.L("WARN_RESET_POSITION"), isDangerous = true, func = function() FG.Graph.ResetPosition() end,
			width = "half", disabled = Hidden,
		},
		{ type = "header", name = FG.L("NUMBERS") },
		{
			type = "button", name = "|cFF0000" .. FG.L("RESET_NUMBERS") .. "|r", warning = FG.L("WARN_RESET_NUMBERS"), isDangerous = true, func = function() FG.ResetStats() end, width = "half",
		},
		{
			type = "button", name = FG.L("RESET_TO_DEFAULTS"), warning = FG.L("PUTS_EVERY_SETTING_ON_THIS_PANEL"),
			isDangerous = true,
			func = function()
				FG.ResetToDefaults()
				FG.Print(FG.L("SETTINGS_ARE_BACK_TO_THEIR_DEFAULTS"), true)
			end,
			width = "half",
		},
	}
end

function FG.BuildSettingsPanel()
	local lam_version, lam_enabled = LibAPH.CheckLibraryVersion("LibAddonMenu-2.0")
	if not lam_enabled or lam_version < REQUIRED_LAM then
		WarnAboutSettingsLibraries()
		return false
	end
	local lam = LibAddonMenu2
	if not lam then return false end
	lam:RegisterAddonPanel(PANEL_ID, {
		type = "panel",
		name = "|c9CD04CAPH-FPSGraph|r",
		displayName = "|c00FFFFAPH-FPSGraph|r",
		author = "|ca500f3A|r|cb400e6P|r|cc300daH|r|cd200cdO|r|ce100c1NlC|r",
		version = FG.VERSION,
		registerForRefresh = true,
		translation = "https://www.esoui.com/portal.php?id=360&a=featurereq",
		donation = "https://buymeacoffee.com/aph0nlc",
	})
	lam:RegisterOptionControls(PANEL_ID, FG.SettingsControls())
	WarnAboutSettingsLibraries()
	return true
end
