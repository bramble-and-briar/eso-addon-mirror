--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

APHProfilerCore = APHProfilerCore or {}
local APHP = APHProfilerCore

APHP.name = "APH-Profiler"
APHP.VERSION = "2026.10.15.14.36"
APHP.KEYBIND_LAYER = "APH-Profiler"

function APHP.L(key, ...)
	local id = _G["SI_APHP_" .. key]
	local text = id and GetString(id) or key
	if select("#", ...) > 0 then return string.format(text, ...) end
	return text
end

local DEFAULTS = {
	exclude_self = true,
	exclude_libraries = true,
	frames_per_tick = 25,
	report_rows = 15,
	scan_mode = "until_stop",
	scan_seconds = IsConsoleUI() and 30 or 60,
	detail_rows = 20,
	open_window_after_scan = true,
	scan_status = true,
	pad_hints = true,
	summary_hide_game_ui = false,
	summary_hide_gc = false,
	scan_load_times = false,
	profile_ui_load = false,
	chat_logs = false,
	hud_locked = false,
	show_hud = false,
	hud_font_size = 14,
	show_previous_scan = true,
	max_saved_runs = 10,
	max_rows_per_run = 200,
	log_to_debuglogger = true,
	warned_about_libraries = false,
}

ZO_CreateStringId("SI_BINDING_NAME_APHPROFILER_TOGGLE_HUD", "Show/Hide Results Window")
ZO_CreateStringId("SI_BINDING_NAME_APHPROFILER_MOVE_HUD", "Move Results Window")
ZO_CreateStringId("SI_BINDING_NAME_APHPROFILER_FOCUS_HUD", "Focus Results Window")
ZO_CreateStringId("SI_BINDING_NAME_APHPROFILER_HUD_MENU", "Results Window Menu")
ZO_CreateStringId("SI_BINDING_NAME_APHPROFILER_HUD_UP", "Results Window Up")
ZO_CreateStringId("SI_BINDING_NAME_APHPROFILER_HUD_DOWN", "Results Window Down")
ZO_CreateStringId("SI_BINDING_NAME_APHPROFILER_HUD_SELECT", "Results Window Select")
ZO_CreateStringId("SI_BINDING_NAME_APHPROFILER_HUD_SCAN", "Results Window Scan")
ZO_CreateStringId("SI_BINDING_NAME_APHPROFILER_HUD_MENU_PAD", "Results Window Menu (controller)")
ZO_CreateStringId("SI_BINDING_NAME_APHPROFILER_HUD_SUMMARY", "Results Window Summary")
ZO_CreateStringId("SI_BINDING_NAME_APHPROFILER_HUD_TIMELINE", "Results Window Timeline")
ZO_CreateStringId("SI_BINDING_NAME_APHPROFILER_HUD_PAGE_UP", "Results Window Page Up")
ZO_CreateStringId("SI_BINDING_NAME_APHPROFILER_HUD_PAGE_DOWN", "Results Window Page Down")
ZO_CreateStringId("SI_BINDING_NAME_APHPROFILER_HUD_PAN_LEFT", "Results Window Pan Left")
ZO_CreateStringId("SI_BINDING_NAME_APHPROFILER_HUD_PAN_RIGHT", "Results Window Pan Right")
ZO_CreateStringId("SI_BINDING_NAME_APHPROFILER_HUD_MOVE_PAD", "Results Window Move (controller)")
ZO_CreateStringId("SI_BINDING_NAME_APHPROFILER_HUD_RESIZE", "Results Window Resize")
ZO_CreateStringId("SI_BINDING_NAME_APHPROFILER_HUD_BACK", "Results Window Back")

function APHP.Print(text, always)
	if not always and APHP.saved and APHP.saved.chat_logs == false then return false end
	LibAPH.SendRawChatLine("|c9CD04C[APHP]|r " .. text)
	return true
end

function APHP.Format(ms)
	if ms >= 1000 then return string.format("%.2f s", ms / 1000) end
	if ms >= 1 then return string.format("%.2f ms", ms) end
	if ms >= 0.01 then return string.format("%.0f us", ms * 1000) end
	return string.format("%.1f us", ms * 1000)
end

function APHP.ResetToDefaults()
	for key, value in pairs(DEFAULTS) do APHP.saved[key] = value end
end

local function Init()
	LibAPH.RegisterAddonDependencies(APHP.name, { "LibAPH" },
		{ "LibAddonMenu-2.0", "LibHarvensAddonSettings", "LibDebugLogger" })
	APHP.saved = ZO_SavedVars:NewAccountWide("APHProfiler", 1, GetWorldName() or "Default", DEFAULTS)
	for key, value in pairs(DEFAULTS) do
		if APHP.saved[key] == nil then APHP.saved[key] = value end
	end

	LibAPH.RegisterKeybindDefaults("APHProfiler", APHP.saved, {
		APHPROFILER_TOGGLE_HUD = KEY_F8,
		APHPROFILER_MOVE_HUD = KEY_GAMEPAD_RIGHT_STICK,
		APHPROFILER_FOCUS_HUD = KEY_GAMEPAD_LEFT_STICK,
		APHPROFILER_HUD_MENU = KEY_GAMEPAD_BUTTON_3,
	})
	LibAPH.RunWhenPlayerActivated(APHP.name .. "_QuietDebugLogger", APHP.QuietDebugLoggerOnConsole)

	APHP.ResumeUiLoadScan()

	SLASH_COMMANDS["/aphp"] = function() APHP.Start() end
	SLASH_COMMANDS["/aphpstop"] = function() APHP.Stop() end
	SLASH_COMMANDS["/aphpreport"] = function() APHP.ShowLastReport() end
	SLASH_COMMANDS["/aphpwindow"] = function() APHP.ToggleHud() end
	if not IsConsoleUI() then SLASH_COMMANDS["/aphpexport"] = function() APHP.ShowExport() end end

	LibAPH.RunInitStages(APHP.name, {
		function() end,
		APHP.BuildSettingsPanel,
		function()
			if not APHP.saved.show_hud then return end
			if (APHP.IsRunning() or APHP.IsParsing()) and APHP.KeepAsideUntilScanDone() then return end
			APHP.ShowHud()
		end,
	})
end

EVENT_MANAGER:RegisterForEvent(APHP.name, EVENT_ADD_ON_LOADED, function(_, name)
	if name ~= APHP.name then return end
	EVENT_MANAGER:UnregisterForEvent(APHP.name, EVENT_ADD_ON_LOADED)
	Init()
end)

APHP.DEFAULTS = DEFAULTS
